public with sharing class EmpreendimentosIntegracaoFinalizer implements Finalizer {

    public void execute(FinalizerContext context) {
        // Sucesso, ou falha já tratada e logada pelo Service: nada a fazer
        if (context.getResult() != ParentJobResult.UNHANDLED_EXCEPTION) {
            return;
        }
        Exception excecao = context.getException();
        OrgOriginEmpreendimentosService.registrarFalhaNaoTratada(excecao.getTypeName(), excecao.getMessage());
    }
}