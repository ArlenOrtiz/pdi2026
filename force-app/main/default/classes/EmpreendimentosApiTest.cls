@IsTest
private class EmpreendimentosApiTest {

    @IsTest
    static void deveClassificar401ComoAutenticacao() {
        assertFalha(new EmpreendimentosApiMocks.ConsultarNaoAutorizadoMock(),
            EmpreendimentosApi.TIPO_AUTENTICACAO, 401);
    }

    @IsTest
    static void deveClassificar503ComoIndisponivel() {
        assertFalha(new EmpreendimentosApiMocks.ConsultarIndisponivelMock(),
            EmpreendimentosApi.TIPO_INDISPONIVEL, 503);
    }

        @IsTest
    static void deveClassificarFalhaNoTokenComoAutenticacao() {
        assertFalha(new EmpreendimentosApiMocks.ConsultarTokenInvalidoMock(),
            EmpreendimentosApi.TIPO_AUTENTICACAO, null);
    }

    @IsTest
    static void deveClassificarTimeoutComoIndisponivel() {
        assertFalha(new EmpreendimentosApiMocks.ConsultarExcecaoCalloutMock(),
            EmpreendimentosApi.TIPO_INDISPONIVEL, null);
    }

    @IsTest
    static void deveClassificarJsonInvalidoComoRespostaInvalida() {
        assertFalha(new EmpreendimentosApiMocks.ConsultarCorpoInvalidoMock(),
            EmpreendimentosApi.TIPO_RESPOSTA_INVALIDA, null);
    }

    @IsTest
    static void deveClassificarOutrosStatusComoRejeitada() {
        assertFalha(new EmpreendimentosApiMocks.RespostaMock(400, '[{"errorCode":"MALFORMED_QUERY"}]'),
            EmpreendimentosApi.TIPO_REJEITADA, 400);
    }

    // Chama a API e garante que ela lança IntegracaoException com o tipo e o status esperados
    private static void assertFalha(HttpCalloutMock mock, String tipoEsperado, Integer statusEsperado) {
        Test.setMock(HttpCalloutMock.class, mock);
        try {
            EmpreendimentosApi.consultarEmpreendimentos();
            Assert.fail('Deveria ter lançado IntegracaoException do tipo ' + tipoEsperado);
        } catch (EmpreendimentosApi.IntegracaoException e) {
            Assert.areEqual(tipoEsperado, e.tipo, 'Tipo de erro incorreto');
            Assert.areEqual(statusEsperado, e.statusCode, 'Status HTTP incorreto');
            Assert.isNotNull(e.getMessage(), 'A mensagem de erro deve ser preenchida');
        }
    }
        @IsTest
    static void deveSeguirPaginacaoDeEmpreendimentosEUnidades() {
        Test.setMock(HttpCalloutMock.class, new EmpreendimentosApiMocks.ConsultarPaginadoMock());

        List<EmpreendimentosDTO.EmpreendimentoDTO> lista = EmpreendimentosApi.consultarEmpreendimentos();

        Assert.areEqual(2, lista.size(), 'Deve juntar os empreendimentos das duas páginas');
        Assert.areEqual(3, EmpreendimentosApiMocks.chamadasPaginado,
            'Deve fazer 3 callouts: página 1, página 2 e página extra de unidades');

        EmpreendimentosDTO.EmpreendimentoDTO primeiro = lista[0];
        Assert.areEqual(EmpreendimentosTestFactory.COD_EMP_EXISTENTE, primeiro.codigo, 'A ordem das páginas deve ser mantida');
        Assert.areEqual(2, primeiro.unidades.size(), 'Deve juntar as unidades da página extra');
        Assert.isTrue(primeiro.unidadesDone, 'A paginação de unidades deve terminar com done = true');
    }
        @IsTest
    static void deveClassificarPaginacaoSemProximaUrlComoRespostaInvalida() {
        // done = false sem nextRecordsUrl: sem a validação, o código chamaria "callout:CA_OrgBasenull"
        assertFalha(new EmpreendimentosApiMocks.RespostaMock(200, '{"done":false,"records":[]}'),
            EmpreendimentosApi.TIPO_RESPOSTA_INVALIDA, null);
    }

    @IsTest
    static void deveClassificarJsonInvalidoNaPaginaDeUnidadesComoRespostaInvalida() {
        assertFalha(new EmpreendimentosApiMocks.RoteadoMock(
                EmpreendimentosTestFactory.corpoPagina1(),
                new Map<String, String>{
                    EmpreendimentosTestFactory.URL_PAGINA_2 => EmpreendimentosTestFactory.corpoPagina2(),
                    EmpreendimentosTestFactory.URL_UNIDADES_2 => '<html>isto nao e JSON</html>'
                }),
            EmpreendimentosApi.TIPO_RESPOSTA_INVALIDA, null);
    }
}