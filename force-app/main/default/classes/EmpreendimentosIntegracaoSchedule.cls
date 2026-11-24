public with sharing class EmpreendimentosIntegracaoSchedule implements Schedulable {

    public static final String NOME_JOB = 'Integracao Empreendimentos Org Base';
    public static final String CRON_A_CADA_4H = '0 0 0/4 * * ?';

    public void execute(SchedulableContext context) {
        System.enqueueJob(new EmpreendimentosIntegracaoQueueable());
    }

    public static Id agendar() {
        return System.schedule(NOME_JOB, CRON_A_CADA_4H, new EmpreendimentosIntegracaoSchedule());
    }
}