/**
 * Nível 3 da hierarquia de APIs (IT-561 §4.2): a ação concreta.
 * Só informa endpoint, método HTTP e objeto de origem.
 */
public class OrgOriginGetEmpreendimentosApi extends OrgOriginApiBase {

    private static final String SOQL =
          'SELECT Name, CA_CodigoEmpreendimento__c, CA_Cidade__c, CA_UF__c, CA_Status__c, CA_PrevisaoEntrega__c, '
        + '(SELECT Name, CA_CodigoUnidade__c, CA_Andar__c, CA_Status__c, CA_AreaPrivativa__c, '
        + 'CA_Dormitorios__c, CA_Vagas__c, CA_ValorTabela__c FROM Unidades__r) '
        + 'FROM CA_Empreendimento__c';

    private String endpointPath = API_PATH + '/query?q=' + EncodingUtil.urlEncode(SOQL, 'UTF-8');

    // Paginação: o nextRecordsUrl já vem como caminho completo (/services/data/vXX.X/query/...)
    public void irParaProximaPagina(String nextRecordsUrl) {
        this.endpointPath = nextRecordsUrl;
    }

    protected override String getEndpointPath() {
        return this.endpointPath;
    }

    protected override String getHttpMethod() {
        return 'GET';
    }

    protected override String getSourceObject() {
        return 'CA_Empreendimento__c';
    }
}