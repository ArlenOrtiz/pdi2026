/**
 * Nível 1 da hierarquia de APIs (IT-561 §4.2).
 * Define o contrato de toda integração HTTP e concentra o que é comum:
 * envio, status, resposta, classificação da falha e dados de log de cada chamada.
 */
public abstract class ApiBase {

    // ===== Tipos de falha (genéricos para qualquer sistema) =====
    public static final String FALHA_AUTENTICACAO = 'AUTENTICACAO';
    public static final String FALHA_INDISPONIVEL = 'INDISPONIVEL';
    public static final String FALHA_REJEITADA = 'REJEITADA';

    private static final Integer HTTP_NAO_AUTORIZADO = 401;
    private static final Integer HTTP_ERRO_SERVIDOR = 500;

    private HttpResponse response;
    private String erroConexao;
    private List<LogsDTO> logs = new List<LogsDTO>();

    // ===== Contrato =====
    // Nível 2 ({Sistema}ApiBase): o que é comum ao sistema
    protected abstract String getBaseUrl();
    protected abstract String getSystemName();
    // Nível 3 ({Sistema}{Metodo}{Entidade}Api): a ação concreta
    protected abstract String getEndpointPath();
    protected abstract String getHttpMethod();
    protected abstract String getSourceObject();

    protected virtual Map<String, String> getHeaders() {
        return new Map<String, String>{ 'Content-Type' => 'application/json' };
    }

    protected virtual Integer getTimeout() {
        return 120000;
    }

    // ===== Envio =====
    public void send(String payload) {
        this.response = null;
        this.erroConexao = null;

        HttpRequest req = new HttpRequest();
        req.setMethod(this.getHttpMethod());
        req.setEndpoint(this.getBaseUrl() + this.getEndpointPath());
        req.setTimeout(this.getTimeout());
        Map<String, String> headers = this.getHeaders();
        for (String chave : headers.keySet()) {
            req.setHeader(chave, headers.get(chave));
        }
        if (payload != null) {
            req.setBody(payload);
        }

        try {
            this.response = new Http().send(req);
        } catch (CalloutException e) {
            // Rede, timeout ou falha ao obter o token da Named Credential: não há resposta HTTP
            this.erroConexao = e.getMessage();
        }
        this.logs.add(this.montarLog(payload));
    }

    // ===== Resultado =====
    public Boolean isSuccess() {
        return this.response != null
            && this.response.getStatusCode() >= 200
            && this.response.getStatusCode() < 300;
    }

    public Integer getStatusCode() {
        return this.response != null ? this.response.getStatusCode() : null;
    }

    public String getResponseBody() {
        return this.response != null ? this.response.getBody() : null;
    }

    public List<LogsDTO> getLogs() {
        return this.logs;
    }

    public LogsDTO getUltimoLog() {
        return this.logs.isEmpty() ? null : this.logs[this.logs.size() - 1];
    }

    // ===== Classificação da falha =====
    public String getTipoFalha() {
        if (this.isSuccess()) {
            return null;
        }
        if (this.erroConexao != null) {
            // Com Named Credential, credencial inválida não gera 401: a plataforma
            // falha ao obter o token e lança CalloutException
            return this.erroConexao.containsIgnoreCase('OAuth token') ? FALHA_AUTENTICACAO : FALHA_INDISPONIVEL;
        }
        Integer status = this.getStatusCode();
        if (status == HTTP_NAO_AUTORIZADO) {
            return FALHA_AUTENTICACAO;
        }
        if (status >= HTTP_ERRO_SERVIDOR) {
            return FALHA_INDISPONIVEL;
        }
        return FALHA_REJEITADA;
    }

    public String getMensagemFalha() {
        String tipo = this.getTipoFalha();
        if (tipo == null) {
            return null;
        }
        String causa = this.erroConexao != null ? this.erroConexao : 'HTTP ' + this.getStatusCode();
        if (tipo == FALHA_AUTENTICACAO) {
            return 'Falha de autenticação em ' + this.getSystemName() + ': ' + causa;
        }
        if (tipo == FALHA_INDISPONIVEL) {
            return this.getSystemName() + ' indisponível: ' + causa;
        }
        return 'Requisição rejeitada por ' + this.getSystemName() + ': ' + causa;
    }

    // ===== Dados de log de cada chamada =====
    private LogsDTO montarLog(String payload) {
        LogsDTO log = new LogsDTO();
        log.method = this.getHttpMethod();
        log.endpoint = this.getBaseUrl() + this.getEndpointPath();
        log.payload = payload;
        log.response = this.erroConexao != null ? this.erroConexao : this.getResponseBody();
        log.statusCode = this.getStatusCode();
        log.source = this.getSourceObject();
        log.detail = 'Integração de ' + this.getSourceObject() + ' com ' + this.getSystemName();
        log.userId = UserInfo.getUserId();
        return log;
    }
}