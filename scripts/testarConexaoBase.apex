HttpRequest req = new HttpRequest();
req.setEndpoint('callout:CA_OrgBase/services/data/v67.0/query?q=' + EncodingUtil.urlEncode(
    'SELECT Name, CA_CodigoEmpreendimento__c, CA_Cidade__c, CA_UF__c, CA_Status__c, CA_PrevisaoEntrega__c, '
  + '(SELECT Name, CA_CodigoUnidade__c, CA_Andar__c, CA_Status__c, CA_AreaPrivativa__c, CA_Dormitorios__c, CA_Vagas__c, CA_ValorTabela__c FROM Unidades__r) '
  + 'FROM CA_Empreendimento__c', 'UTF-8'));
req.setMethod('GET');
HttpResponse res = new Http().send(req);
EmpreendimentosDTO.PaginaDTO p = EmpreendimentosDTO.parse(res.getBody());
System.debug('Empreendimentos: ' + p.empreendimentos.size() + ' | done: ' + p.done);
for (EmpreendimentosDTO.EmpreendimentoDTO e : p.empreendimentos) {
    System.debug(e.codigo + ' | ' + e.nome + ' | entrega ' + e.previsaoEntrega
        + ' | unidades: ' + e.unidades.size() + ' | unidadesDone: ' + e.unidadesDone);
}
System.debug('1ª unidade: ' + JSON.serializePretty(p.empreendimentos[0].unidades[0]));