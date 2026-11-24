@IsTest
private class OrgOriginGetEmpreendimentosApiTest {

    @IsTest
    static void deveMontarRequisicaoERegistrarDadosDaChamadaEmCasoDeSucesso() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());
        OrgOriginGetEmpreendimentosApi api = new OrgOriginGetEmpreendimentosApi();

        api.send(null);

        Assert.isTrue(api.isSuccess(), 'HTTP 200 deve ser sucesso');
        Assert.areEqual(200, api.getStatusCode(), 'Status HTTP incorreto');
        Assert.isNotNull(api.getResponseBody(), 'O corpo da resposta deve ser exposto');
        Assert.isNull(api.getTipoFalha(), 'Sucesso não tem tipo de falha');
        Assert.isNull(api.getMensagemFalha(), 'Sucesso não tem mensagem de falha');

        Assert.areEqual(1, api.getLogs().size(), 'Cada chamada deve gerar os dados de 1 log');
        LogsDTO log = api.getUltimoLog();
        Assert.areEqual('GET', log.method, 'Método HTTP no log');
        Assert.isTrue(log.endpoint.startsWith('callout:CA_OrgBase' + OrgOriginApiBase.API_PATH + '/query?q='),
            'Endpoint = Named Credential (nível 2) + caminho da query (nível 3)');
        Assert.areEqual('CA_Empreendimento__c', log.source, 'Objeto de origem no log');
    }

    @IsTest
    static void deveUsarAProximaPaginaComoEndpoint() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarPaginadoMock());
        OrgOriginGetEmpreendimentosApi api = new OrgOriginGetEmpreendimentosApi();

        api.irParaProximaPagina(EmpreendimentosTestFactory.URL_PAGINA_2);
        api.send(null);

        Assert.areEqual('callout:CA_OrgBase' + EmpreendimentosTestFactory.URL_PAGINA_2, api.getUltimoLog().endpoint,
            'O nextRecordsUrl deve ser usado como caminho, sem nova codificação');
    }

    @IsTest
    static void deveEnviarCorpoQuandoInformado() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());
        OrgOriginGetEmpreendimentosApi api = new OrgOriginGetEmpreendimentosApi();

        api.send('{"teste":true}');

        Assert.areEqual('{"teste":true}', api.getUltimoLog().payload, 'O payload enviado deve ir para o log');
    }

    @IsTest
    static void deveClassificar401ComoAutenticacao() {
        assertFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarNaoAutorizadoMock(), ApiBase.FALHA_AUTENTICACAO, 401);
    }

    @IsTest
    static void deveClassificarFalhaNoTokenComoAutenticacao() {
        assertFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarTokenInvalidoMock(), ApiBase.FALHA_AUTENTICACAO, null);
    }

    @IsTest
    static void deveClassificar503ComoIndisponivel() {
        assertFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarIndisponivelMock(), ApiBase.FALHA_INDISPONIVEL, 503);
    }

    @IsTest
    static void deveClassificarTimeoutComoIndisponivel() {
        OrgOriginGetEmpreendimentosApi api =
            assertFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarExcecaoCalloutMock(), ApiBase.FALHA_INDISPONIVEL, null);
        Assert.isTrue(api.getUltimoLog().response.contains('Read timed out'),
            'Sem resposta HTTP, o log deve guardar a mensagem da exceção');
    }

    @IsTest
    static void deveClassificarOutrosStatusComoRejeitada() {
        assertFalha(new OrgOriginGetEmpreendimentosApiMocks.RespostaMock(400, '[{"errorCode":"MALFORMED_QUERY"}]'),
            ApiBase.FALHA_REJEITADA, 400);
    }

    // Envia e garante que a falha foi classificada com o tipo e o status esperados
    private static OrgOriginGetEmpreendimentosApi assertFalha(HttpCalloutMock mock, String tipoEsperado, Integer statusEsperado) {
        Test.setMock(HttpCalloutMock.class, mock);
        OrgOriginGetEmpreendimentosApi api = new OrgOriginGetEmpreendimentosApi();

        api.send(null);

        Assert.isFalse(api.isSuccess(), 'A chamada não deve ser considerada sucesso');
        Assert.areEqual(tipoEsperado, api.getTipoFalha(), 'Tipo de falha incorreto');
        Assert.areEqual(statusEsperado, api.getStatusCode(), 'Status HTTP incorreto');
        Assert.isTrue(api.getMensagemFalha().contains('Org Base'), 'A mensagem deve citar o sistema de origem');
        Assert.areEqual(1, api.getLogs().size(), 'A falha também deve gerar os dados de log');
        return api;
    }
}