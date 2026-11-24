@IsTest
private class EmpreendimentosIntegracaoTest {

    @IsTest
    static void queueableDeveExecutarAImportacao() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());

        Test.startTest();
        System.enqueueJob(new EmpreendimentosIntegracaoQueueable());
        Test.stopTest();   // executa o Queueable

        Assert.areEqual(2, [SELECT COUNT() FROM CA_Empreendimento__c],
            'O Queueable deve chamar o Service e gravar os empreendimentos');
    }

    @IsTest
    static void scheduleDeveAgendarACada4Horas() {
        // O job real já existe na org com esse nome. Abortamos aqui para o teste não dar
        // "already scheduled". Tudo que o teste faz é desfeito no fim, então o job real não é afetado.
        for (CronTrigger existente : [
                SELECT Id FROM CronTrigger
                WHERE CronJobDetail.Name = :EmpreendimentosIntegracaoSchedule.NOME_JOB]) {
            System.abortJob(existente.Id);
        }
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());

        Test.startTest();
        Id jobId = EmpreendimentosIntegracaoSchedule.agendar();
        Test.stopTest();   // dispara o Schedule, que enfileira o Queueable

        CronTrigger agendado = [
            SELECT CronExpression, CronJobDetail.Name, State
            FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(EmpreendimentosIntegracaoSchedule.CRON_A_CADA_4H, agendado.CronExpression,
            'O job deve usar o cron de 4 em 4 horas');
        Assert.areEqual(EmpreendimentosIntegracaoSchedule.NOME_JOB, agendado.CronJobDetail.Name,
            'O job deve usar o nome padrão');
    }
}