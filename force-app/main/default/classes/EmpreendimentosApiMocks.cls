@IsTest
public class EmpreendimentosApiMocks {

    // Base: devolve sempre o mesmo status e corpo
    public virtual class RespostaMock implements HttpCalloutMock {
        protected Integer statusCode;
        protected String corpo;

        public RespostaMock(Integer statusCode, String corpo) {
            this.statusCode = statusCode;
            this.corpo = corpo;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(corpo);
            return res;
        }
    }

    public class ConsultarSucessoMock extends RespostaMock {
        public ConsultarSucessoMock() {
            super(200, EmpreendimentosTestFactory.corpoSucesso());
        }
    }

    public class ConsultarNaoAutorizadoMock extends RespostaMock {
        public ConsultarNaoAutorizadoMock() {
            super(401, '[{"message":"Session expired or invalid","errorCode":"INVALID_SESSION_ID"}]');
        }
    }

    public class ConsultarIndisponivelMock extends RespostaMock {
        public ConsultarIndisponivelMock() {
            super(503, 'Service Unavailable');
        }
    }

    public class ConsultarCorpoInvalidoMock extends RespostaMock {
        public ConsultarCorpoInvalidoMock() {
            super(200, '<html>isto nao e JSON</html>');
        }
    }

    // Simula timeout ou falha de rede: não há resposta HTTP
    public class ConsultarExcecaoCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Read timed out');
        }
    }
        // Contador de chamadas do mock paginado.
    // Fica na classe externa porque, em Apex, só a classe de topo pode ter membros static.
    public static Integer chamadasPaginado = 0;

    // Responde conforme a URL chamada, simulando várias páginas
    public class ConsultarPaginadoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            chamadasPaginado++;
            String endpoint = req.getEndpoint();
            String corpo;
            if (endpoint.endsWith(EmpreendimentosTestFactory.URL_PAGINA_2)) {
                corpo = EmpreendimentosTestFactory.corpoPagina2();
            } else if (endpoint.endsWith(EmpreendimentosTestFactory.URL_UNIDADES_2)) {
                corpo = EmpreendimentosTestFactory.corpoUnidadesPagina2();
            } else {
                corpo = EmpreendimentosTestFactory.corpoPagina1();
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(corpo);
            return res;
        }
    }

    public class ConsultarUnidadeInvalidaMock extends RespostaMock {
        public ConsultarUnidadeInvalidaMock() {
            super(200, EmpreendimentosTestFactory.corpoUnidadeComStatusInvalido());
        }
    }
        // Responde conforme o final da URL; se nenhum sufixo bater, devolve o corpo padrão
    public class RoteadoMock implements HttpCalloutMock {
        private String corpoPadrao;
        private Map<String, String> corpoPorSufixo;

        public RoteadoMock(String corpoPadrao, Map<String, String> corpoPorSufixo) {
            this.corpoPadrao = corpoPadrao;
            this.corpoPorSufixo = corpoPorSufixo;
        }

        public HttpResponse respond(HttpRequest req) {
            String corpo = corpoPadrao;
            for (String sufixo : corpoPorSufixo.keySet()) {
                if (req.getEndpoint().endsWith(sufixo)) {
                    corpo = corpoPorSufixo.get(sufixo);
                }
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(corpo);
            return res;
        }
    }
        // Mensagem real capturada na evidência do Passo 7 (secret inválido)
    public class ConsultarTokenInvalidoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Unable to fetch the OAuth token. Error: invalid_client. '
                + 'Error description: invalid client credentials.');
        }
    }
}