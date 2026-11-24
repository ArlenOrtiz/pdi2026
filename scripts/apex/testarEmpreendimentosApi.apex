List<EmpreendimentosDTO.EmpreendimentoDTO> lista = EmpreendimentosApi.consultarEmpreendimentos();
System.debug('Total: ' + lista.size());
for (EmpreendimentosDTO.EmpreendimentoDTO e : lista) {
    System.debug(e.codigo + ' -> ' + e.unidades.size());
}