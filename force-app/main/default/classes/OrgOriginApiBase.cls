/**
 * Nível 2 da hierarquia de APIs (IT-561 §4.2): o padrão do sistema de origem (Org Base).
 * Tudo que é comum às integrações com esse sistema fica aqui.
 */
public abstract class OrgOriginApiBase extends ApiBase {

    // Versão da REST API da org de origem, centralizada para todas as APIs do sistema
    public static final String API_PATH = '/services/data/v67.0';

    protected override String getBaseUrl() {
        return 'callout:CA_OrgBase';
    }

    protected override String getSystemName() {
        return 'Org Base';
    }

    protected override Integer getTimeout() {
        return 60000;
    }
}