public class CodeLogger implements Queueable {
    private List<LogsDTO> logsList;
    

    public CodeLogger(List<LogsDTO> logsList) {
        this.logsList = logsList;
    }

    public void execute(QueueableContext context) {
        try {
            List<CA_Log__c> logsToInsert = new List<CA_Log__c>();
            for (LogsDTO logData : logsList) {
                logsToInsert.add(new CA_Log__c(
                    CA_Type__c = logData.type,
                    CA_Method__c = logData.method,
                    CA_Detail__c = logData.detail,
                    CA_Endpoint__c = logData.endpoint,
                    CA_Payload__c = logData.payload != null ? logData.payload.left(131072) : null,
                    CA_Response__c = logData.response != null ? logData.response.left(131072) : null,
                    CA_Source__c = logData.source,
                    CA_StatusCode__c = logData.statusCode,
                    CA_User__c = logData.userId,
                    CA_ErrorDescription__c = logData.errorDescription
                ));
            }
            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
                System.debug('Logs criados com sucesso. Total: ' + logsToInsert.size());
            }
        } catch (DmlException e) {
            System.debug('Falha ao inserir logs: ' + e.getMessage());
        }
    }

    public static void createLog(LogsDTO logData) {
        System.enqueueJob(new CodeLogger(new List<LogsDTO>{logData}));
    }

    public static void createLogs(List<LogsDTO> logsList) {
        if (logsList != null && !logsList.isEmpty()) {
            System.enqueueJob(new CodeLogger(logsList));
        }
    }

    public static void createLog(String type, String method, String detail, String endpoint, 
                                String payload, String response, String source, Integer statusCode, Id userId, String errorDescription) {
        LogsDTO dto = new LogsDTO();
        dto.type = type;
        dto.method = method;
        dto.detail = detail;
        dto.endpoint = endpoint;
        dto.payload = payload;
        dto.response = response;
        dto.source = source;
        dto.statusCode = statusCode;
        dto.userId = userId;
        dto.errorDescription = errorDescription;
        System.enqueueJob(new CodeLogger(new List<LogsDTO>{dto}));        
    }

    public static LogsDTO createLogDTO(String type, String method, String detail, String endpoint, String payload, String response, String source, Integer statusCode, Id userId, String errorDescription) {
        LogsDTO log = new LogsDTO();
        log.type = type;
        log.method = method;
        log.detail = detail;
        log.endpoint = endpoint;
        log.payload = payload;
        log.response = response;
        log.source = source;
        log.statusCode = statusCode;
        log.userId = userId;
        log.errorDescription = errorDescription;
        return log;
    }

    public static void insertLogsDirectly(List<LogsDTO> logsList) {
        if (logsList != null && !logsList.isEmpty()) {
            try {
                List<CA_Log__c> logsToInsert = new List<CA_Log__c>();
                for (LogsDTO logData : logsList) {
                    logsToInsert.add(new CA_Log__c(
                        CA_Type__c = logData.type,
                        CA_Method__c = logData.method,
                        CA_Detail__c = logData.detail,
                        CA_Endpoint__c = logData.endpoint,
                        CA_Payload__c = logData.payload != null ? logData.payload.left(131072) : null,
                        CA_Response__c = logData.response != null ? logData.response.left(131072) : null,
                        CA_Source__c = logData.source,
                        CA_StatusCode__c = logData.statusCode,
                        CA_User__c = logData.userId,
                        CA_ErrorDescription__c = logData.errorDescription
                    ));
                }
                if (!logsToInsert.isEmpty()) {
                    insert logsToInsert;
                }
            } catch (DmlException e) {
                System.debug('Falha ao inserir logs diretamente: ' + e.getMessage());
            }
        }
    }

    @InvocableMethod(label='Criar Log' description='Cria um log de atividade')
    public static void invocableCreateLog(List<LogRequest> requests) {
        for (LogRequest req : requests) {
            createLog(req.type, req.method, req.detail, req.endpoint, req.payload, req.response, req.source, req.statusCode, UserInfo.getUserId(), req.errorDescription);
        }
    }

    public class LogRequest {
        @InvocableVariable(label='Type')
        public String type;

        @InvocableVariable(label='Method')
        public String method;

        @InvocableVariable(label='Detalhe')
        public String detail;

        @InvocableVariable(label='Payload')
        public String payload;

        @InvocableVariable(label='Response')
        public String response;

        @InvocableVariable(label='Endpoint')
        public String endpoint;

        @InvocableVariable(label='Source')
        public String source;

        @InvocableVariable(label='Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Error Description')
        public String errorDescription;
    }
}