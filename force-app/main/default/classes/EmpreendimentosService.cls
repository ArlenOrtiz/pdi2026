public with sharing class EmpreendimentosService {

    // ===== Constantes de log =====
    public static final String TIPO_GRAVACAO = 'GRAVACAO';
    public static final String TIPO_NAO_TRATADA = 'NAO_TRATADA';
    private static final String LOG_TIPO = 'ERROR';
    private static final String LOG_METODO = 'GET'; // CA_Method__c guarda o método HTTP (Text(20) no pacote CodeLogger)
    private static final String LOG_ORIGEM = 'Integracao Org Base';
    private static final String LOG_ENDPOINT = 'callout:CA_OrgBase';

    // ===== Ponto de entrada =====
    public static void importar() {
        // 1. TODOS os callouts primeiro: nada foi gravado ainda
        List<EmpreendimentosDTO.EmpreendimentoDTO> dtos;
        try {
            dtos = EmpreendimentosApi.consultarEmpreendimentos();
        } catch (EmpreendimentosApi.IntegracaoException e) {
            registrarFalha(e.tipo, e.getMessage(), e.statusCode, e.corpo);
            return;
        }
        gravar(dtos);
    }

    // Chamado pelo Finalizer quando o Queue termina com exceção não tratada (ex.: LimitException)
    public static void registrarFalhaNaoTratada(String tipoExcecao, String mensagem) {
        registrarFalha(TIPO_NAO_TRATADA, tipoExcecao + ': ' + mensagem, null, null);
    }

    // ===== Gravação atômica =====
    private static void gravar(List<EmpreendimentosDTO.EmpreendimentoDTO> dtos) {
        // 2. Converter DTO -> sObjects (só memória)
        List<CA_Empreendimento__c> empreendimentos = new List<CA_Empreendimento__c>();
        List<CA_Unidade__c> unidades = new List<CA_Unidade__c>();
        Datetime agora = Datetime.now();

        for (EmpreendimentosDTO.EmpreendimentoDTO dto : dtos) {
            empreendimentos.add(montarEmpreendimento(dto, agora));
            for (EmpreendimentosDTO.UnidadeDTO unidade : dto.unidades) {
                unidades.add(montarUnidade(unidade, dto.codigo));
            }
        }

        // 3. Savepoint ANTES do primeiro DML
        Savepoint sp = Database.setSavepoint();

        // 4 e 5. Upsert por ID externo com allOrNone = false: a plataforma devolve
        // o resultado de cada registro, e conseguimos logar TODOS os erros com o código.
        // As unidades só são gravadas se todos os empreendimentos passaram.
        List<String> erros = coletarErros(
            Database.upsert(empreendimentos, CA_Empreendimento__c.CA_CodigoEmpreendimento__c, false),
            empreendimentos, CA_Empreendimento__c.CA_CodigoEmpreendimento__c);
        if (erros.isEmpty()) {
            erros.addAll(coletarErros(
                Database.upsert(unidades, CA_Unidade__c.CA_CodigoUnidade__c, false),
                unidades, CA_Unidade__c.CA_CodigoUnidade__c));
        }

        // Qualquer erro: desfaz TUDO (atomicidade) e loga a lista completa
        if (!erros.isEmpty()) {
            Database.rollback(sp);
            registrarFalha(TIPO_GRAVACAO,
                'Falha ao gravar ' + erros.size() + ' registro(s): ' + String.join(erros, ' | '),
                null, null);
        }
    }

    // Monta "CODIGO: mensagem [campos]" para cada registro que falhou
    private static List<String> coletarErros(
            List<Database.UpsertResult> resultados, List<SObject> registros, Schema.SObjectField campoCodigo) {
        List<String> erros = new List<String>();
        for (Integer i = 0; i < resultados.size(); i++) {
            if (resultados[i].isSuccess()) {
                continue;
            }
            for (Database.Error erro : resultados[i].getErrors()) {
                erros.add(registros[i].get(campoCodigo) + ': ' + erro.getMessage() + ' ' + erro.getFields());
            }
        }
        return erros;
    }

    // ===== Conversões DTO -> sObject =====
    private static CA_Empreendimento__c montarEmpreendimento(
            EmpreendimentosDTO.EmpreendimentoDTO dto, Datetime agora) {
        return new CA_Empreendimento__c(
            Name = dto.nome,
            CA_CodigoEmpreendimento__c = dto.codigo,
            CA_Cidade__c = dto.cidade,
            CA_UF__c = dto.uf,
            CA_Status__c = dto.status,
            CA_PrevisaoEntrega__c = dto.previsaoEntrega,
            CA_DataUltimaIntegracao__c = agora
        );
    }

    private static CA_Unidade__c montarUnidade(
            EmpreendimentosDTO.UnidadeDTO dto, String codigoEmpreendimento) {
        return new CA_Unidade__c(
            Name = dto.nome,
            CA_CodigoUnidade__c = dto.codigo,
            // Liga ao pai pelo código externo, sem SOQL
            CA_Empreendimento__r = new CA_Empreendimento__c(
                CA_CodigoEmpreendimento__c = codigoEmpreendimento),
            CA_Andar__c = dto.andar,
            CA_Status__c = dto.status,
            CA_AreaPrivativa__c = dto.areaPrivativa,
            CA_Dormitorios__c = dto.dormitorios,
            CA_Vagas__c = dto.vagas,
            CA_ValorTabela__c = dto.valorTabela
        );
    }

    // ===== Único ponto de log por transação (CodeLogger enfileira 1 Queueable) =====
    private static void registrarFalha(String tipo, String mensagem, Integer statusCode, String corpo) {
        CodeLogger.createLog(
            LOG_TIPO,                                                       // type
            limitar(LOG_METODO, CA_Log__c.CA_Method__c),                    // method
            limitar(tipo + ': ' + mensagem, CA_Log__c.CA_Detail__c),        // detail
            LOG_ENDPOINT,                                                   // endpoint
            null,                                                           // payload (GET não envia corpo)
            limitar(corpo, CA_Log__c.CA_Response__c),                       // response
            LOG_ORIGEM,                                                     // source
            statusCode,                                                     // statusCode
            UserInfo.getUserId(),                                           // userId
            limitar(mensagem, CA_Log__c.CA_ErrorDescription__c)             // errorDescription
        );
    }

    // Corta o texto no tamanho real do campo (lido da org): um texto grande
    // faria o insert do log falhar, e o CodeLogger engole esse erro em silêncio
    private static String limitar(String texto, Schema.SObjectField campo) {
        if (texto == null) {
            return null;
        }
        return texto.abbreviate(campo.getDescribe().getLength());
    }
}