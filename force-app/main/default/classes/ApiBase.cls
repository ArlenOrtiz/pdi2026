public abstract class ApiBase {
    private HttpResponse response;
    private List<LogsDTO> logs;
    protected abstract String getEndpointPath();
    protected abstract String getHttpMethod();
    protected abstract String getSourceObject();
    protected abstract String getBaseUrl();
    protected abstract String getSystemName();
    protected virtual Map<String, String> getHeaders() {
        return new Map<String, String>{
            'Content-Type' => 'application/json'
        };
    }
    protected virtual Integer getTimeout() {
        return 120000;
    }
    public ApiBase() {
        this.logs = new List<LogsDTO>();
    }
    public Boolean isSuccess() {
        return this.response != null
            && this.response.getStatusCode() >= 200
            && this.response.getStatusCode() < 300;
    }
    public String getResponseBody() {
        return this.response != null ? this.response.getBody() : null;
    }
    public Integer getStatusCode() {
        return this.response != null ? this.response.getStatusCode() : null;
    }
    public List<LogsDTO> getLogs() {
        return this.logs;
    }
    public void send(String payload) {
        HttpRequest req = new HttpRequest();
        req.setMethod(this.getHttpMethod());
        req.setEndpoint(this.getBaseUrl() + this.getEndpointPath());
        req.setBody(payload);
        req.setTimeout(this.getTimeout());
        for (String key : this.getHeaders().keySet()) {
            req.setHeader(key, this.getHeaders().get(key));
        }
        Http http = new Http();
        HttpResponse res = http.send(req);
        this.response = res;
        this.logs.add(CodeLogger.createLogDTO(
            this.getSystemName(),
            this.getHttpMethod(),
            'Integração de ' + this.getSourceObject() + ' com ' + this.getSystemName(),
            this.getBaseUrl() + this.getEndpointPath(),
            payload,
            res.getBody(),
            this.getSourceObject(),
            res.getStatusCode(),
            UserInfo.getUserId(),
            null
        ));
    }
}