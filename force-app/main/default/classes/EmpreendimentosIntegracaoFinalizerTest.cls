@IsTest
private class EmpreendimentosIntegracaoFinalizerTest {

    // Contexto falso: simula o resultado do Queue sem precisar provocar um limite real
    private class ContextoFalso implements FinalizerContext {
        private ParentJobResult resultado;
        private Exception excecao;

        ContextoFalso(ParentJobResult resultado, Exception excecao) {
            this.resultado = resultado;
            this.excecao = excecao;
        }
        public Id getAsyncApexJobId() { return null; }
        public String getRequestId() { return null; }
        public ParentJobResult getResult() { return resultado; }
        public Exception getException() { return excecao; }
    }

    @IsTest
    static void deveRegistrarLogQuandoQueueTerminaComExcecaoNaoTratada() {
        Test.startTest();
        new EmpreendimentosIntegracaoFinalizer().execute(
            new ContextoFalso(ParentJobResult.UNHANDLED_EXCEPTION, new TypeException('Erro inesperado')));
        Test.stopTest();   // executa o Queueable do CodeLogger

        List<CA_Log__c> logs = [SELECT CA_Detail__c FROM CA_Log__c];
        Assert.areEqual(1, logs.size(), 'A falha não tratada deve gerar exatamente 1 log');
        Assert.isTrue(logs[0].CA_Detail__c.startsWith(OrgOriginEmpreendimentosService.TIPO_NAO_TRATADA),
            'O log deve identificar a falha como não tratada');
        Assert.isTrue(logs[0].CA_Detail__c.contains('Erro inesperado'),
            'O log deve conter a mensagem original da exceção');
    }

    @IsTest
    static void naoDeveRegistrarLogQuandoQueueTerminaComSucesso() {
        Test.startTest();
        new EmpreendimentosIntegracaoFinalizer().execute(
            new ContextoFalso(ParentJobResult.SUCCESS, null));
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM CA_Log__c],
            'Execução com sucesso (ou com falha já tratada) não deve gerar log no Finalizer');
    }
}