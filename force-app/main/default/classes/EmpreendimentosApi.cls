public with sharing class EmpreendimentosApi {

    // ===== Configuração =====
    private static final String NAMED_CREDENTIAL = 'callout:CA_OrgBase';
    private static final String PATH_QUERY = '/services/data/v67.0/query?q=';
    private static final Integer TIMEOUT_MS = 60000;
    private static final String SOQL =
          'SELECT Name, CA_CodigoEmpreendimento__c, CA_Cidade__c, CA_UF__c, CA_Status__c, CA_PrevisaoEntrega__c, '
        + '(SELECT Name, CA_CodigoUnidade__c, CA_Andar__c, CA_Status__c, CA_AreaPrivativa__c, '
        + 'CA_Dormitorios__c, CA_Vagas__c, CA_ValorTabela__c FROM Unidades__r) '
        + 'FROM CA_Empreendimento__c';

    // ===== Códigos HTTP =====
    private static final Integer HTTP_OK = 200;
    private static final Integer HTTP_NAO_AUTORIZADO = 401;
    private static final Integer HTTP_ERRO_SERVIDOR = 500;

    // ===== Tipos de erro (públicos: o Service e os testes usam) =====
    public static final String TIPO_AUTENTICACAO = 'AUTENTICACAO';
    public static final String TIPO_INDISPONIVEL = 'INDISPONIVEL';
    public static final String TIPO_REJEITADA = 'REJEITADA';
    public static final String TIPO_RESPOSTA_INVALIDA = 'RESPOSTA_INVALIDA';

    // ===== Exceção tipada: carrega o "porquê" da falha até o Service =====
    public class IntegracaoException extends Exception {
        public String tipo;
        public Integer statusCode;
        public String corpo;

        public IntegracaoException(String tipo, String mensagem, Integer statusCode, String corpo) {
            this.setMessage(mensagem);
            this.tipo = tipo;
            this.statusCode = statusCode;
            this.corpo = corpo;
        }
    }

    // ===== Ponto de entrada =====
    public static List<EmpreendimentosDTO.EmpreendimentoDTO> consultarEmpreendimentos() {
        List<EmpreendimentosDTO.EmpreendimentoDTO> todos = new List<EmpreendimentosDTO.EmpreendimentoDTO>();

        // Primeira página
        EmpreendimentosDTO.PaginaDTO pagina =
            lerPagina(enviar(PATH_QUERY + EncodingUtil.urlEncode(SOQL, 'UTF-8')));
        todos.addAll(pagina.empreendimentos);

        // Próximas páginas de empreendimentos
        while (!pagina.done) {
            pagina = lerPagina(enviar(pagina.nextRecordsUrl));
            todos.addAll(pagina.empreendimentos);
        }

        // Páginas extras de unidades de cada empreendimento
        for (EmpreendimentosDTO.EmpreendimentoDTO emp : todos) {
            completarUnidades(emp);
        }
        return todos;
    }

    private static void completarUnidades(EmpreendimentosDTO.EmpreendimentoDTO emp) {
        validarPaginacao(emp.unidadesDone, emp.unidadesNextRecordsUrl, null);

        while (!emp.unidadesDone) {
            EmpreendimentosDTO.PaginaUnidadesDTO pagina =
                lerPaginaUnidades(enviar(emp.unidadesNextRecordsUrl));
            emp.unidades.addAll(pagina.unidades);
            emp.unidadesDone = pagina.done;
            emp.unidadesNextRecordsUrl = pagina.nextRecordsUrl;
        }
    }

    // ===== Parse protegido: erro de conteúdo vira RESPOSTA_INVALIDA =====
    private static EmpreendimentosDTO.PaginaDTO lerPagina(String body) {
        EmpreendimentosDTO.PaginaDTO pagina;
        try {
            pagina = EmpreendimentosDTO.parse(body);
        } catch (Exception e) {
            throw respostaInvalida(body);
        }
        validarPaginacao(pagina.done, pagina.nextRecordsUrl, body);
        return pagina;
    }

    private static EmpreendimentosDTO.PaginaUnidadesDTO lerPaginaUnidades(String body) {
        EmpreendimentosDTO.PaginaUnidadesDTO pagina;
        try {
            pagina = EmpreendimentosDTO.parseUnidades(body);
        } catch (Exception e) {
            throw respostaInvalida(body);
        }
        validarPaginacao(pagina.done, pagina.nextRecordsUrl, body);
        return pagina;
    }

    // Garante que o loop nunca rode com done nulo ou sem URL da próxima página
    private static void validarPaginacao(Boolean done, String proximaUrl, String corpo) {
        if (done == null || (!done && String.isBlank(proximaUrl))) {
            throw respostaInvalida(corpo);
        }
    }

    private static IntegracaoException respostaInvalida(String corpo) {
        return new IntegracaoException(TIPO_RESPOSTA_INVALIDA,
            'Resposta inválida da org Base', null, corpo);
    }

    // ===== Infraestrutura HTTP =====
    private static String enviar(String path) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + path);
        req.setMethod('GET');
        req.setTimeout(TIMEOUT_MS);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            // Com Named Credential, credencial inválida não gera HTTP 401:
            // a plataforma falha ao obter o token e lança CalloutException
            if (isFalhaDeToken(e.getMessage())) {
                throw new IntegracaoException(TIPO_AUTENTICACAO,
                    'Falha de autenticação na org Base: ' + e.getMessage(), null, null);
            }
            throw new IntegracaoException(TIPO_INDISPONIVEL,
                'Org Base indisponível: ' + e.getMessage(), null, null);
        }
        validarResposta(res);
        return res.getBody();
    }

    private static Boolean isFalhaDeToken(String mensagem) {
        return mensagem != null && mensagem.containsIgnoreCase('OAuth token');
    }

    private static void validarResposta(HttpResponse res) {
        Integer status = res.getStatusCode();
        if (status == HTTP_OK) {
            return;
        }
        if (status == HTTP_NAO_AUTORIZADO) {
            throw new IntegracaoException(TIPO_AUTENTICACAO,
                'Falha de autenticação na org Base (HTTP 401)', status, res.getBody());
        }
        if (status >= HTTP_ERRO_SERVIDOR) {
            throw new IntegracaoException(TIPO_INDISPONIVEL,
                'Org Base indisponível (HTTP ' + status + ')', status, res.getBody());
        }
        throw new IntegracaoException(TIPO_REJEITADA,
            'Requisição rejeitada pela org Base (HTTP ' + status + ')', status, res.getBody());
    }
}