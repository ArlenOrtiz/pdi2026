/**
 * Regra de negócio da integração: buscar empreendimentos e unidades da org de origem
 * e gravar na Explorer de forma atômica (IT-561 §4.3.3, {Funcionalidade}Service).
 */
public with sharing class OrgOriginEmpreendimentosService {

    // ===== Tipos de falha próprios do Service (os de transporte vêm da ApiBase) =====
    public static final String TIPO_RESPOSTA_INVALIDA = 'RESPOSTA_INVALIDA';
    public static final String TIPO_GRAVACAO = 'GRAVACAO';
    public static final String TIPO_NAO_TRATADA = 'NAO_TRATADA';

    private static final String LOG_TIPO = 'ERROR';
    private static final String LOG_METODO = 'OrgOriginEmpreendimentosService.importar';
    private static final String LOG_ORIGEM = 'Integracao Org Base';
    private static final String LOG_ENDPOINT = 'callout:CA_OrgBase';

    // Interrompe a busca e leva o motivo (e os dados da chamada) até o importar()
    private class FalhaIntegracaoException extends Exception {
        public String tipo;
        public LogsDTO logApi;

        public FalhaIntegracaoException(String tipo, String mensagem, LogsDTO logApi) {
            this.setMessage(mensagem);
            this.tipo = tipo;
            this.logApi = logApi;
        }
    }

    // ===== Ponto de entrada =====
    public static void importar() {
        // 1. TODOS os callouts primeiro: nada foi gravado ainda
        List<EmpreendimentosDTO.EmpreendimentoDTO> dtos;
        try {
            dtos = consultarEmpreendimentos(new OrgOriginGetEmpreendimentosApi());
        } catch (FalhaIntegracaoException e) {
            registrarFalha(e.tipo, e.getMessage(), e.logApi);
            return;
        }
        gravar(dtos);
    }

    // Chamado pelo Finalizer quando o Queue termina com exceção não tratada (ex.: LimitException)
    public static void registrarFalhaNaoTratada(String tipoExcecao, String mensagem) {
        registrarFalha(TIPO_NAO_TRATADA, tipoExcecao + ': ' + mensagem, null);
    }

    // ===== Busca completa: todas as páginas de empreendimentos e de unidades =====
    @TestVisible
    private static List<EmpreendimentosDTO.EmpreendimentoDTO> consultarEmpreendimentos(OrgOriginGetEmpreendimentosApi api) {
        List<EmpreendimentosDTO.EmpreendimentoDTO> todos = new List<EmpreendimentosDTO.EmpreendimentoDTO>();

        EmpreendimentosDTO.PaginaDTO pagina = lerPagina(api, enviar(api));
        todos.addAll(pagina.empreendimentos);

        while (!pagina.done) {
            api.irParaProximaPagina(pagina.nextRecordsUrl);
            pagina = lerPagina(api, enviar(api));
            todos.addAll(pagina.empreendimentos);
        }

        for (EmpreendimentosDTO.EmpreendimentoDTO emp : todos) {
            completarUnidades(api, emp);
        }
        return todos;
    }

    private static void completarUnidades(OrgOriginGetEmpreendimentosApi api, EmpreendimentosDTO.EmpreendimentoDTO emp) {
        validarPaginacao(emp.unidadesDone, emp.unidadesNextRecordsUrl, api);

        while (!emp.unidadesDone) {
            api.irParaProximaPagina(emp.unidadesNextRecordsUrl);
            EmpreendimentosDTO.PaginaUnidadesDTO pagina = lerPaginaUnidades(api, enviar(api));
            emp.unidades.addAll(pagina.unidades);
            emp.unidadesDone = pagina.done;
            emp.unidadesNextRecordsUrl = pagina.nextRecordsUrl;
        }
    }

    // Envia pela API; se a chamada falhar, interrompe com o tipo classificado pela ApiBase
    private static String enviar(OrgOriginGetEmpreendimentosApi api) {
        api.send(null);
        if (!api.isSuccess()) {
            throw new FalhaIntegracaoException(api.getTipoFalha(), api.getMensagemFalha(), api.getUltimoLog());
        }
        return api.getResponseBody();
    }

    // ===== Parse protegido: conteúdo fora do contrato vira RESPOSTA_INVALIDA =====
    private static EmpreendimentosDTO.PaginaDTO lerPagina(OrgOriginGetEmpreendimentosApi api, String body) {
        EmpreendimentosDTO.PaginaDTO pagina;
        try {
            pagina = EmpreendimentosDTO.parse(body);
        } catch (Exception e) {
            throw respostaInvalida(api);
        }
        validarPaginacao(pagina.done, pagina.nextRecordsUrl, api);
        return pagina;
    }

    private static EmpreendimentosDTO.PaginaUnidadesDTO lerPaginaUnidades(OrgOriginGetEmpreendimentosApi api, String body) {
        EmpreendimentosDTO.PaginaUnidadesDTO pagina;
        try {
            pagina = EmpreendimentosDTO.parseUnidades(body);
        } catch (Exception e) {
            throw respostaInvalida(api);
        }
        validarPaginacao(pagina.done, pagina.nextRecordsUrl, api);
        return pagina;
    }

    // Garante que o loop nunca rode com done nulo ou sem URL da próxima página
    private static void validarPaginacao(Boolean done, String proximaUrl, OrgOriginGetEmpreendimentosApi api) {
        if (done == null || (!done && String.isBlank(proximaUrl))) {
            throw respostaInvalida(api);
        }
    }

    private static FalhaIntegracaoException respostaInvalida(OrgOriginGetEmpreendimentosApi api) {
        return new FalhaIntegracaoException(TIPO_RESPOSTA_INVALIDA, 'Resposta inválida da org Base', api.getUltimoLog());
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

        // 4 e 5. Upsert por ID externo com allOrNone = false: devolve o resultado de cada
        // registro, para logar TODOS os erros com o código. Unidades só se todos os empreendimentos passaram.
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
                'Falha ao gravar ' + erros.size() + ' registro(s): ' + String.join(erros, ' | '), null);
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
    // Quando a falha veio da API, aproveita os dados da chamada montados pela ApiBase
    private static void registrarFalha(String tipo, String mensagem, LogsDTO logApi) {
        LogsDTO log = logApi != null ? logApi : new LogsDTO();
        log.type = LOG_TIPO;
        log.detail = limitar(tipo + ': ' + mensagem, CA_Log__c.CA_Detail__c);
        log.errorDescription = limitar(mensagem, CA_Log__c.CA_ErrorDescription__c);
        log.method = limitar(log.method != null ? log.method : LOG_METODO, CA_Log__c.CA_Method__c);
        log.endpoint = limitar(log.endpoint != null ? log.endpoint : LOG_ENDPOINT, CA_Log__c.CA_Endpoint__c);
        log.source = limitar(log.source != null ? log.source : LOG_ORIGEM, CA_Log__c.CA_Source__c);
        log.payload = limitar(log.payload, CA_Log__c.CA_Payload__c);
        log.response = limitar(log.response, CA_Log__c.CA_Response__c);
        log.userId = UserInfo.getUserId();
        CodeLogger.createLog(log);
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