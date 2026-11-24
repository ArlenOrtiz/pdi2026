public with sharing class EmpreendimentosIntegracaoQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        // Garante log mesmo se o job terminar com exceção não tratada (ex.: LimitException)
        System.attachFinalizer(new EmpreendimentosIntegracaoFinalizer());
        OrgOriginEmpreendimentosService.importar();
    }
}