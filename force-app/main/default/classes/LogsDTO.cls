public class LogsDTO {
    @AuraEnabled public Id id;
    @AuraEnabled public Datetime createdDate;
    @AuraEnabled public String type;
    @AuraEnabled public String method;
    @AuraEnabled public String detail;
    @AuraEnabled public Decimal statusCode;
    @AuraEnabled public String source;
    @AuraEnabled public String payload;
    @AuraEnabled public String response;
    @AuraEnabled public String endpoint;
    @AuraEnabled public String errorDescription;
    @AuraEnabled public Id userId;
    
    public LogsDTO() {}
    
    public LogsDTO(CA_Log__c log) {
        this.id = log.Id;
        this.createdDate = log.CreatedDate;
        this.type = log.CA_Type__c;
        this.method = log.CA_Method__c;
        this.detail = log.CA_Detail__c;
        this.statusCode = log.CA_StatusCode__c;
        this.source = log.CA_Source__c;
        this.payload = log.CA_Payload__c;
        this.response = log.CA_Response__c;
        this.endpoint = log.CA_Endpoint__c;
        this.userId = log.CA_User__c;
        this.errorDescription = log.CA_ErrorDescription__c;
    }
}