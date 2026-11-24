@IsTest
public class EmpreendimentosTestFactory {

    public static final String COD_EMP_EXISTENTE = 'EMP001';
    public static final String COD_EMP_NOVO = 'EMP002';
    public static final String PERMISSION_SET_EXECUTOR = 'CA_IntegracaoOrgBaseExecutor';

    // ===== Valores de picklist válidos na org (lidos do describe) =====
    public static String uf() {
        return primeiroValor(CA_Empreendimento__c.CA_UF__c);
    }

    public static String statusEmpreendimento() {
        return primeiroValor(CA_Empreendimento__c.CA_Status__c);
    }

    public static String statusUnidade() {
        return primeiroValor(CA_Unidade__c.CA_Status__c);
    }

    private static String primeiroValor(Schema.SObjectField campo) {
        return campo.getDescribe().getPicklistValues()[0].getValue();
    }

    // ===== sObjects montados SEM DML (IT-561: o teste faz o insert) =====
    public static CA_Empreendimento__c buildEmpreendimento(String codigo, String nome) {
        return new CA_Empreendimento__c(
            Name = nome,
            CA_CodigoEmpreendimento__c = codigo,
            CA_Cidade__c = 'Cidade Antiga',
            CA_UF__c = uf(),
            CA_Status__c = statusEmpreendimento()
        );
    }

    public static CA_Unidade__c buildUnidade(Id empreendimentoId, String codigo) {
        return new CA_Unidade__c(
            Name = 'Antiga ' + codigo,
            CA_CodigoUnidade__c = codigo,
            CA_Empreendimento__c = empreendimentoId,
            CA_Status__c = statusUnidade(),
            CA_ValorTabela__c = 100000
        );
    }

    // Usuário que agenda o job: perfil de administrador (+ Permission Set de executor, atribuído no teste)
    public static User buildUsuarioExecutor() {
        Profile perfil = [
            SELECT Id FROM Profile
            WHERE Name IN ('System Administrator', 'Administrador do sistema')
            LIMIT 1
        ];
        String sufixo = String.valueOf(System.now().getTime());
        return new User(
            ProfileId = perfil.Id,
            LastName = 'Executor Integracao',
            Alias = 'exec' + sufixo.right(4),
            Email = 'executor.integracao@pdi.test',
            Username = 'executor.integracao.' + sufixo + '@pdi.test',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            LocaleSidKey = 'pt_BR',
            TimeZoneSidKey = 'America/Sao_Paulo'
        );
    }

    // ===== JSON no mesmo formato da API REST de query =====
    public static String corpoSucesso() {
        return JSON.serialize(pagina(new List<Object>{
            empreendimento(COD_EMP_EXISTENTE, 'Residencial Alfa', new List<Object>{
                unidade('UN001', 500000),
                unidade('UN002', 520000.50)
            }),
            empreendimento(COD_EMP_NOVO, 'Residencial Beta', new List<Object>{
                unidade('UN003', 610000),
                unidade('UN004', 630000)
            })
        }, true, null));
    }

    public static Map<String, Object> pagina(List<Object> records, Boolean done, String nextRecordsUrl) {
        Map<String, Object> pagina = new Map<String, Object>{
            'totalSize' => records.size(),
            'done' => done,
            'records' => records
        };
        if (nextRecordsUrl != null) {
            pagina.put('nextRecordsUrl', nextRecordsUrl);
        }
        return pagina;
    }

    public static Map<String, Object> empreendimento(String codigo, String nome, List<Object> unidades) {
        return new Map<String, Object>{
            'Name' => nome,
            'CA_CodigoEmpreendimento__c' => codigo,
            'CA_Cidade__c' => 'Curitiba',
            'CA_UF__c' => uf(),
            'CA_Status__c' => statusEmpreendimento(),
            'CA_PrevisaoEntrega__c' => '2027-11-08',
            'Unidades__r' => pagina(unidades, true, null)
        };
    }

    public static Map<String, Object> unidade(String codigo, Decimal valorTabela) {
        return new Map<String, Object>{
            'Name' => 'Unidade ' + codigo,
            'CA_CodigoUnidade__c' => codigo,
            'CA_Andar__c' => 1,
            'CA_Status__c' => statusUnidade(),
            'CA_AreaPrivativa__c' => 68.5,
            'CA_Dormitorios__c' => 2,
            'CA_Vagas__c' => 1,
            'CA_ValorTabela__c' => valorTabela
        };
    }

    // ===== Paginação =====
    public static final String URL_PAGINA_2 = '/services/data/v67.0/query/01gPAGINA-2000';
    public static final String URL_UNIDADES_2 = '/services/data/v67.0/query/01gUNIDADES-2000';

    public static String corpoPagina1() {
        Map<String, Object> emp = empreendimento(COD_EMP_EXISTENTE, 'Residencial Alfa', new List<Object>());
        emp.put('Unidades__r', pagina(new List<Object>{ unidade('UN001', 500000) }, false, URL_UNIDADES_2));
        return JSON.serialize(pagina(new List<Object>{ emp }, false, URL_PAGINA_2));
    }

    public static String corpoPagina2() {
        return JSON.serialize(pagina(new List<Object>{
            empreendimento(COD_EMP_NOVO, 'Residencial Beta', new List<Object>{
                unidade('UN003', 610000),
                unidade('UN004', 630000)
            })
        }, true, null));
    }

    public static String corpoUnidadesPagina2() {
        return JSON.serialize(pagina(new List<Object>{ unidade('UN002', 520000.50) }, true, null));
    }

    // ===== Falha na gravação: unidades com status inexistente na picklist restrita =====
    public static String corpoUnidadeComStatusInvalido() {
        Map<String, Object> invalida = unidade('UN003', 610000);
        invalida.put('CA_Status__c', 'StatusInexistente');
        return JSON.serialize(pagina(new List<Object>{
            empreendimento(COD_EMP_EXISTENTE, 'Residencial Alfa', new List<Object>{ unidade('UN001', 500000) }),
            empreendimento(COD_EMP_NOVO, 'Residencial Beta', new List<Object>{ invalida })
        }, true, null));
    }

    // Duas unidades inválidas: prova que o log traz TODOS os erros, com os códigos
    public static String corpoDuasUnidadesComStatusInvalido() {
        Map<String, Object> unidade3 = unidade('UN003', 610000);
        unidade3.put('CA_Status__c', 'StatusInexistente');
        Map<String, Object> unidade4 = unidade('UN004', 630000);
        unidade4.put('CA_Status__c', 'StatusInexistente');
        return JSON.serialize(pagina(new List<Object>{
            empreendimento(COD_EMP_NOVO, 'Residencial Beta', new List<Object>{ unidade3, unidade4 })
        }, true, null));
    }
}