/**
 * DTO da integração Base → Explorer.
 * Traduz o JSON da REST API (query com subquery) em objetos Apex tipados.
 * Não contém regra de negócio e não trata erros: um dado fora do contrato
 * lança exceção, que a EmpreendimentosApi converte em RESPOSTA_INVALIDA.
 */
public class EmpreendimentosDTO {

    // ===== Nomes do contrato (JSON da Base) centralizados num só lugar =====
    private static final String JSON_DONE     = 'done';
    private static final String JSON_NEXT_URL = 'nextRecordsUrl';
    private static final String JSON_RECORDS  = 'records';
    private static final String JSON_UNIDADES = 'Unidades__r';

    // ===== Estruturas =====

    /** Uma página da resposta principal (lista de empreendimentos). */
    public class PaginaDTO {
        public Boolean done;
        public String nextRecordsUrl;
        public List<EmpreendimentoDTO> empreendimentos = new List<EmpreendimentoDTO>();
    }

    /** Uma página de unidades (dentro de Unidades__r ou vinda de um nextRecordsUrl de unidades). */
    public class PaginaUnidadesDTO {
        public Boolean done = true;
        public String nextRecordsUrl;
        public List<UnidadeDTO> unidades = new List<UnidadeDTO>();
    }

    public class EmpreendimentoDTO {
        public String codigo;            // CA_CodigoEmpreendimento__c (ID externo)
        public String nome;              // Name
        public String cidade;            // CA_Cidade__c
        public String uf;                // CA_UF__c (API name da picklist)
        public String status;            // CA_Status__c (API name da picklist)
        public Date previsaoEntrega;     // CA_PrevisaoEntrega__c
        public List<UnidadeDTO> unidades = new List<UnidadeDTO>();
        public Boolean unidadesDone = true;      // Unidades__r.done
        public String unidadesNextRecordsUrl;    // Unidades__r.nextRecordsUrl
    }

    public class UnidadeDTO {
        public String codigo;            // CA_CodigoUnidade__c (ID externo)
        public String nome;              // Name
        public Decimal andar;            // CA_Andar__c
        public String status;            // CA_Status__c
        public Decimal areaPrivativa;    // CA_AreaPrivativa__c
        public Decimal dormitorios;      // CA_Dormitorios__c
        public Decimal vagas;            // CA_Vagas__c
        public Decimal valorTabela;      // CA_ValorTabela__c
    }

    // ===== Métodos públicos (pontos de entrada) =====

    /** Converte o corpo da resposta principal da query. */
    public static PaginaDTO parse(String body) {
        Map<String, Object> raiz = (Map<String, Object>) JSON.deserializeUntyped(body);

        PaginaDTO pagina = new PaginaDTO();
        pagina.done = (Boolean) raiz.get(JSON_DONE);
        pagina.nextRecordsUrl = (String) raiz.get(JSON_NEXT_URL);

        for (Object registro : lerRecords(raiz)) {
            pagina.empreendimentos.add(montarEmpreendimento((Map<String, Object>) registro));
        }
        return pagina;
    }

    /** Converte o corpo de uma página extra de unidades (quando Unidades__r veio com done = false). */
    public static PaginaUnidadesDTO parseUnidades(String body) {
        return montarPaginaUnidades((Map<String, Object>) JSON.deserializeUntyped(body));
    }

    // ===== Montagem =====

    private static EmpreendimentoDTO montarEmpreendimento(Map<String, Object> registro) {
        EmpreendimentoDTO dto = new EmpreendimentoDTO();
        dto.codigo          = (String) registro.get('CA_CodigoEmpreendimento__c');
        dto.nome            = (String) registro.get('Name');
        dto.cidade          = (String) registro.get('CA_Cidade__c');
        dto.uf              = (String) registro.get('CA_UF__c');
        dto.status          = (String) registro.get('CA_Status__c');
        dto.previsaoEntrega = paraData(registro.get('CA_PrevisaoEntrega__c'));

        // Unidades__r vem null quando o empreendimento não tem unidades
        Map<String, Object> relacionamento = (Map<String, Object>) registro.get(JSON_UNIDADES);
        if (relacionamento != null) {
            PaginaUnidadesDTO paginaUnidades = montarPaginaUnidades(relacionamento);
            dto.unidades               = paginaUnidades.unidades;
            dto.unidadesDone           = paginaUnidades.done;
            dto.unidadesNextRecordsUrl = paginaUnidades.nextRecordsUrl;
        }
        return dto;
    }

    private static PaginaUnidadesDTO montarPaginaUnidades(Map<String, Object> mapa) {
        PaginaUnidadesDTO pagina = new PaginaUnidadesDTO();
        pagina.done = (Boolean) mapa.get(JSON_DONE);
        pagina.nextRecordsUrl = (String) mapa.get(JSON_NEXT_URL);

        for (Object registro : lerRecords(mapa)) {
            pagina.unidades.add(montarUnidade((Map<String, Object>) registro));
        }
        return pagina;
    }

    private static UnidadeDTO montarUnidade(Map<String, Object> registro) {
        UnidadeDTO dto = new UnidadeDTO();
        dto.codigo        = (String) registro.get('CA_CodigoUnidade__c');
        dto.nome          = (String) registro.get('Name');
        dto.andar         = paraDecimal(registro.get('CA_Andar__c'));
        dto.status        = (String) registro.get('CA_Status__c');
        dto.areaPrivativa = paraDecimal(registro.get('CA_AreaPrivativa__c'));
        dto.dormitorios   = paraDecimal(registro.get('CA_Dormitorios__c'));
        dto.vagas         = paraDecimal(registro.get('CA_Vagas__c'));
        dto.valorTabela   = paraDecimal(registro.get('CA_ValorTabela__c'));
        return dto;
    }

    // ===== Conversão: nulo continua nulo; valor fora do contrato lança exceção =====

    private static List<Object> lerRecords(Map<String, Object> mapa) {
        Object records = mapa.get(JSON_RECORDS);
        return records == null ? new List<Object>() : (List<Object>) records;
    }

    private static Decimal paraDecimal(Object valor) {
        return valor == null ? null : Decimal.valueOf(String.valueOf(valor));
    }

    private static Date paraData(Object valor) {
        return valor == null ? null : Date.valueOf((String) valor);
    }
}