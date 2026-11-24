@IsTest
private class EmpreendimentosDTOTest {

    @IsTest
    static void deveTratarEmpreendimentoSemUnidadesECamposNulos() {
        String corpo = JSON.serialize(new Map<String, Object>{
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'Name' => 'Sem Unidades',
                    'CA_CodigoEmpreendimento__c' => 'EMP900',
                    'CA_PrevisaoEntrega__c' => null,
                    'Unidades__r' => null
                }
            }
        });

        EmpreendimentosDTO.PaginaDTO pagina = EmpreendimentosDTO.parse(corpo);

        Assert.areEqual(1, pagina.empreendimentos.size(), 'Deve ler o empreendimento');
        EmpreendimentosDTO.EmpreendimentoDTO emp = pagina.empreendimentos[0];
        Assert.areEqual('EMP900', emp.codigo, 'Deve ler o código');
        Assert.isNull(emp.previsaoEntrega, 'Data nula deve continuar nula');
        Assert.areEqual(0, emp.unidades.size(), 'Sem Unidades__r, a lista de unidades deve vir vazia');
        Assert.isTrue(emp.unidadesDone, 'Sem Unidades__r, não há páginas extras de unidades');
    }

    @IsTest
    static void deveTratarPaginaSemRecords() {
        EmpreendimentosDTO.PaginaDTO pagina = EmpreendimentosDTO.parse('{"done":true}');

        Assert.isTrue(pagina.done, 'Deve ler o done');
        Assert.areEqual(0, pagina.empreendimentos.size(), 'Sem records, a lista deve vir vazia');
    }

    @IsTest
    static void deveConverterUnidadeComNumerosNulos() {
        String corpo = JSON.serialize(new Map<String, Object>{
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'CA_CodigoUnidade__c' => 'UN900',
                    'CA_Andar__c' => null,
                    'CA_AreaPrivativa__c' => null,
                    'CA_ValorTabela__c' => null
                }
            }
        });

        EmpreendimentosDTO.PaginaUnidadesDTO pagina = EmpreendimentosDTO.parseUnidades(corpo);

        Assert.areEqual(1, pagina.unidades.size(), 'Deve ler a unidade');
        EmpreendimentosDTO.UnidadeDTO unidade = pagina.unidades[0];
        Assert.areEqual('UN900', unidade.codigo, 'Deve ler o código');
        Assert.isNull(unidade.andar, 'Número nulo deve continuar nulo');
        Assert.isNull(unidade.valorTabela, 'Número nulo deve continuar nulo');
    }
        @IsTest
    static void deveLancarExcecaoQuandoNumeroEstiverForaDoContrato() {
        String corpo = JSON.serialize(new Map<String, Object>{
            'done' => true,
            'records' => new List<Object>{
                new Map<String, Object>{
                    'CA_CodigoUnidade__c' => 'UN901',
                    'CA_ValorTabela__c' => 'abc'
                }
            }
        });

        try {
            EmpreendimentosDTO.parseUnidades(corpo);
            Assert.fail('Valor fora do contrato deve lançar exceção, nunca virar nulo em silêncio');
        } catch (TypeException e) {
            Assert.isNotNull(e.getMessage(), 'A exceção deve explicar o valor inválido');
        }
    }
}