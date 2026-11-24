@IsTest
private class OrgOriginEmpreendimentosServiceTest {

    @TestSetup
    static void setup() {
        // Registro antigo (simula uma importação anterior). O DML fica explícito aqui (IT-561)
        CA_Empreendimento__c existente = EmpreendimentosTestFactory.buildEmpreendimento(
            EmpreendimentosTestFactory.COD_EMP_EXISTENTE, 'Nome Antigo');
        insert existente;
        insert new List<CA_Unidade__c>{
            EmpreendimentosTestFactory.buildUnidade(existente.Id, 'UN001'),
            EmpreendimentosTestFactory.buildUnidade(existente.Id, 'UN002')
        };

        // Usuário que agenda o job (PO-017: testes com perfis dos usuários).
        // O runAs separa o DML de configuração (User) do DML de dados, evitando MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            User executor = EmpreendimentosTestFactory.buildUsuarioExecutor();
            insert executor;
            PermissionSet executorPs = [
                SELECT Id FROM PermissionSet
                WHERE Name = :EmpreendimentosTestFactory.PERMISSION_SET_EXECUTOR];
            insert new PermissionSetAssignment(AssigneeId = executor.Id, PermissionSetId = executorPs.Id);
        }
    }

    // ===== Busca =====

    @IsTest
    static void deveBuscarTodasAsPaginasDeEmpreendimentosEUnidades() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarPaginadoMock());

        List<EmpreendimentosDTO.EmpreendimentoDTO> lista =
            OrgOriginEmpreendimentosService.consultarEmpreendimentos(new OrgOriginGetEmpreendimentosApi());

        Assert.areEqual(2, lista.size(), 'Deve juntar os empreendimentos das duas páginas');
        Assert.areEqual(3, OrgOriginGetEmpreendimentosApiMocks.chamadasPaginado,
            'Deve fazer 3 callouts: página 1, página 2 e página extra de unidades');
        Assert.areEqual(EmpreendimentosTestFactory.COD_EMP_EXISTENTE, lista[0].codigo, 'A ordem das páginas deve ser mantida');
        Assert.areEqual(2, lista[0].unidades.size(), 'Deve juntar as unidades da página extra');
        Assert.isTrue(lista[0].unidadesDone, 'A paginação de unidades deve terminar com done = true');
    }

    // ===== Importação com sucesso =====

    @IsTest
    static void deveInserirNovosEAtualizarExistentesSemDuplicar() {
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());

        Test.startTest();
        OrgOriginEmpreendimentosService.importar();
        Test.stopTest();

        Map<String, CA_Empreendimento__c> porCodigo = new Map<String, CA_Empreendimento__c>();
        for (CA_Empreendimento__c emp : [
                SELECT Name, CA_CodigoEmpreendimento__c, CA_DataUltimaIntegracao__c,
                    (SELECT CA_CodigoUnidade__c, CA_ValorTabela__c FROM Unidades__r ORDER BY CA_CodigoUnidade__c)
                FROM CA_Empreendimento__c]) {
            porCodigo.put(emp.CA_CodigoEmpreendimento__c, emp);
        }

        Assert.areEqual(2, porCodigo.size(), 'Deve haver 1 empreendimento atualizado e 1 novo, sem duplicar');
        Assert.areEqual(4, [SELECT COUNT() FROM CA_Unidade__c], 'Deve haver 2 unidades atualizadas e 2 novas');

        CA_Empreendimento__c existente = porCodigo.get(EmpreendimentosTestFactory.COD_EMP_EXISTENTE);
        Assert.areEqual('Residencial Alfa', existente.Name, 'O nome deve ser atualizado pela importação');
        Assert.areEqual(500000, existente.Unidades__r[0].CA_ValorTabela__c, 'O valor da unidade deve ser atualizado');
        Assert.isNotNull(existente.CA_DataUltimaIntegracao__c, 'A data da última integração deve ser preenchida');

        CA_Empreendimento__c novo = porCodigo.get(EmpreendimentosTestFactory.COD_EMP_NOVO);
        Assert.areEqual(2, novo.Unidades__r.size(), 'As unidades novas devem ser ligadas ao pai pelo código externo');

        Assert.areEqual(0, [SELECT COUNT() FROM CA_Log__c], 'Importação com sucesso não deve gerar log');
    }

    @IsTest
    static void deveImportarComOPerfilDoUsuarioQueAgendaOJob() {
        User executor = [SELECT Id FROM User WHERE Email = 'executor.integracao@pdi.test' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new OrgOriginGetEmpreendimentosApiMocks.ConsultarSucessoMock());

        System.runAs(executor) {
            Test.startTest();
            OrgOriginEmpreendimentosService.importar();
            Test.stopTest();
        }

        CA_Empreendimento__c novo = [
            SELECT CreatedById FROM CA_Empreendimento__c
            WHERE CA_CodigoEmpreendimento__c = :EmpreendimentosTestFactory.COD_EMP_NOVO];
        Assert.areEqual(executor.Id, novo.CreatedById, 'A importação deve rodar com o usuário que agenda o job');
        Assert.areEqual(4, [SELECT COUNT() FROM CA_Unidade__c], 'Com o perfil do executor, todas as unidades devem ser gravadas');
        Assert.areEqual(0, [SELECT COUNT() FROM CA_Log__c], 'Com o perfil do executor, a importação não deve falhar');
    }

    // ===== Falhas na busca: nada gravado, 1 log =====

    @IsTest
    static void naoDeveGravarQuandoNaoAutorizado() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarNaoAutorizadoMock());
        assertDadosIntactosComUmLog();

        // O log aproveita os dados da chamada montados pela ApiBase
        CA_Log__c log = [SELECT CA_Detail__c, CA_StatusCode__c, CA_Endpoint__c FROM CA_Log__c];
        Assert.isTrue(log.CA_Detail__c.startsWith(ApiBase.FALHA_AUTENTICACAO), 'Tipo de falha no log');
        Assert.areEqual(401, log.CA_StatusCode__c.intValue(), 'O status HTTP da chamada deve ir para o log');
        Assert.isTrue(log.CA_Endpoint__c.startsWith('callout:CA_OrgBase'), 'O endpoint da chamada deve ir para o log');
    }

    @IsTest
    static void naoDeveGravarQuandoFalharOTokenOAuth() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarTokenInvalidoMock());
        assertDadosIntactosComUmLog();
        assertTipoDoLog(ApiBase.FALHA_AUTENTICACAO);
    }

    @IsTest
    static void naoDeveGravarQuandoIndisponivel() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarIndisponivelMock());
        assertDadosIntactosComUmLog();
        assertTipoDoLog(ApiBase.FALHA_INDISPONIVEL);
    }

    @IsTest
    static void naoDeveGravarQuandoOcorreTimeout() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarExcecaoCalloutMock());
        assertDadosIntactosComUmLog();
        assertTipoDoLog(ApiBase.FALHA_INDISPONIVEL);
    }

    @IsTest
    static void naoDeveGravarQuandoRespostaInvalida() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarCorpoInvalidoMock());
        assertDadosIntactosComUmLog();
        assertTipoDoLog(OrgOriginEmpreendimentosService.TIPO_RESPOSTA_INVALIDA);
    }

    @IsTest
    static void naoDeveGravarQuandoPaginaDeUnidadesForInvalida() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.RoteadoMock(
            EmpreendimentosTestFactory.corpoPagina1(),
            new Map<String, String>{
                EmpreendimentosTestFactory.URL_PAGINA_2 => EmpreendimentosTestFactory.corpoPagina2(),
                EmpreendimentosTestFactory.URL_UNIDADES_2 => '<html>isto nao e JSON</html>'
            }));
        assertDadosIntactosComUmLog();
        assertTipoDoLog(OrgOriginEmpreendimentosService.TIPO_RESPOSTA_INVALIDA);
    }

    @IsTest
    static void naoDeveGravarQuandoPaginacaoVierSemProximaUrl() {
        // done = false sem nextRecordsUrl: sem a validação, chamaria "callout:CA_OrgBasenull"
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.RespostaMock(200, '{"done":false,"records":[]}'));
        assertDadosIntactosComUmLog();
        assertTipoDoLog(OrgOriginEmpreendimentosService.TIPO_RESPOSTA_INVALIDA);
    }

    @IsTest
    static void deveRegistrarLogMesmoComRespostaMuitoGrande() {
        // 200 mil caracteres não-JSON: gera RESPOSTA_INVALIDA com o corpo inteiro no log
        String corpoGrande = 'x'.repeat(200000);
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.RespostaMock(200, corpoGrande));

        assertDadosIntactosComUmLog();
        CA_Log__c log = [SELECT CA_Response__c FROM CA_Log__c];
        Assert.isTrue(log.CA_Response__c.length() <= CA_Log__c.CA_Response__c.getDescribe().getLength(),
            'O corpo deve ser truncado no tamanho do campo');
    }

    // ===== Falhas na gravação: rollback total, 1 log =====

    @IsTest
    static void deveDesfazerTudoQuandoGravacaoDasUnidadesFalha() {
        // Empreendimentos gravam com sucesso, unidades falham: o rollback deve desfazer os dois
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.ConsultarUnidadeInvalidaMock());
        assertDadosIntactosComUmLog();
        assertTipoDoLog(OrgOriginEmpreendimentosService.TIPO_GRAVACAO);
    }

    @IsTest
    static void deveListarNoLogTodasAsUnidadesComProblemaPeloCodigo() {
        executarComFalha(new OrgOriginGetEmpreendimentosApiMocks.RespostaMock(200,
            EmpreendimentosTestFactory.corpoDuasUnidadesComStatusInvalido()));

        // Atomicidade preservada: EMP002 foi gravado e desfeito; nada mudou
        assertDadosIntactosComUmLog();

        String detalhe = [SELECT CA_Detail__c FROM CA_Log__c].CA_Detail__c;
        Assert.isTrue(detalhe.contains('UN003'), 'O log deve identificar a primeira unidade pelo código');
        Assert.isTrue(detalhe.contains('UN004'), 'O log deve listar todas as unidades com erro, não só a primeira');
        Assert.isTrue(detalhe.contains('CA_Status__c'), 'O log deve indicar o campo com problema');
    }

    // ===== Auxiliares =====
    private static void executarComFalha(HttpCalloutMock mock) {
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        OrgOriginEmpreendimentosService.importar();   // não deve lançar exceção: o Service trata e loga
        Test.stopTest();                               // executa o Queueable do CodeLogger
    }

    private static void assertDadosIntactosComUmLog() {
        // A consulta de 1 linha falha sozinha se houver 0 ou mais de 1 empreendimento
        CA_Empreendimento__c emp = [SELECT Name, CA_DataUltimaIntegracao__c FROM CA_Empreendimento__c];
        Assert.areEqual('Nome Antigo', emp.Name, 'O empreendimento existente não pode ser alterado');
        Assert.isNull(emp.CA_DataUltimaIntegracao__c, 'A data da última integração não pode ser preenchida em falha');
        Assert.areEqual(2, [SELECT COUNT() FROM CA_Unidade__c], 'Nenhuma unidade pode ser criada ou removida');
        Assert.areEqual(1, [SELECT COUNT() FROM CA_Log__c], 'A falha deve gerar exatamente 1 log');
    }

    private static void assertTipoDoLog(String tipoEsperado) {
        String detalhe = [SELECT CA_Detail__c FROM CA_Log__c].CA_Detail__c;
        Assert.isTrue(detalhe.startsWith(tipoEsperado), 'O log deve começar com o tipo ' + tipoEsperado);
    }
}