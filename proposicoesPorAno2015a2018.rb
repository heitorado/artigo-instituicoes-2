require 'rest-client'
require 'json'
require 'logger'

logger = Logger.new("detalhamento.log")

API_URL = "https://dadosabertos.camara.leg.br/api/v2"

# CREUZA = 194258

# Passo 1: Obter todos os deputados da câmara que estiveram em exercício de 2015 a 2018 em PE.
# no caso, esta legislatura (2015-2018) tem código 55 na base de dados abertos.

# deputadosArray = GET "#{API_URL}/deputados?idLegislatura=55&siglaUf=PE&ordem=ASC&ordenarPor=nome"
deputadosArray = []
pagina = 1
res = RestClient.get("#{API_URL}/deputados?idLegislatura=55&siglaUf=PE&ordem=ASC&ordenarPor=nome&pagina=#{pagina}")
res = JSON.parse(res)

res["dados"].each do |d|	
    deputadosArray << d
end

while( !res["links"].select { |link| link["rel"] == "next" }.empty? )
    pagina = pagina+1
    #deputadosArray << JSON.parse(res)["dados"]
    res = RestClient.get("#{API_URL}/deputados?idLegislatura=55&siglaUf=PE&ordem=ASC&ordenarPor=nome&pagina=#{pagina}")
    res = JSON.parse(res)
    res["dados"].each do |d|	
        deputadosArray << d
    end
end

######################################################################

deputadosArray.each do |dept|
    dept_info_hash = {}
    dept_info_hash['nome'] = dept['nome']

    # Passo 2: Para cada deputad@ 'dept', obter todas as Comissões Permanentes (código de órgao '2') onde el@ é ou foi Titular, 
    # no período da legislatura, e guardar todas as siglas destas comissões no array siglasComissoesArray
    siglasComissoesArray = []
    # Pega todos os ÓRGÃOS em que @ deputad@ participou
    # orgaosArray = GET "#{API_URL}/deputados/#{dept['id']}/orgaos?dataInicio=2015-02-01&dataFim=2019-01-31&ordem=ASC&ordenarPor=dataInicio"
    orgaosArray = []
    pagina = 1
    res = RestClient.get("#{API_URL}/deputados/#{dept['id']}/orgaos?dataInicio=2015-02-01&dataFim=2019-01-31&ordem=ASC&ordenarPor=dataInicio&pagina=#{pagina}")
    res = JSON.parse(res)

    res["dados"].each do |d|	
        orgaosArray << d
    end

    while( !res["links"].select { |link| link["rel"] == "next" }.empty? )
        pagina = pagina+1
        #orgaosArray << JSON.parse(res)["dados"]
        res = RestClient.get("#{API_URL}/deputados?idLegislatura=55&siglaUf=PE&ordem=ASC&ordenarPor=nome&pagina=#{pagina}")
        res = JSON.parse(res)
        res["dados"].each do |d|	
            orgaosArray << d
        end
    end


    # Para cada orgao, fazer a respectiva requisição para obter mais detalhes, contanto que o deputado seja titular.
    orgaosArray.each do |orgao|
        if(orgao['titulo'].eql? "Titular")
            # orgao_detalhado = GET "#{API_URL}/orgaos/#{orgao['idOrgao']}"
            # Se o órgão for uma COMISSÃO PERMANENTE (codigo 2) , inclui sua sigla no array.
            res = RestClient.get("#{API_URL}/orgaos/#{orgao['idOrgao']}")
            orgao_detalhado = JSON.parse(res)["dados"]
            
            if(orgao_detalhado['codTipoOrgao'].eql? 2)
                siglasComissoesArray << orgao_detalhado['sigla']
            end
        end
    end

    # Passo 3: Ainda tratando do deputad@ 'dept', listar todas as proposições que autorou em cada ano da legislatura (2015 - 2018)
    # e que são Projetos de Lei
    (2015..2018).each do |ano|
        # propsArray = GET "#{API_URL}/proposicoes?siglaTipo=PL&siglaTipo=PLP&siglaTipo=PLV&siglaTipo=PLC&siglaTipo=PLN&ano=#{ano}&idDeputadoAutor=#{dept['id']}&ordem=ASC&ordenarPor=id"
        propsArray = []
        pagina = 1
        res = RestClient.get("#{API_URL}/proposicoes?siglaTipo=PL&siglaTipo=PLP&siglaTipo=PLV&siglaTipo=PLC&siglaTipo=PLN&ano=#{ano}&idDeputadoAutor=#{dept['id']}&ordem=ASC&ordenarPor=id&pagina=#{pagina}")
        res = JSON.parse(res)

        res["dados"].each do |d|	
            propsArray << d
        end

        while( !res["links"].select { |link| link["rel"] == "next" }.empty? )
            pagina = pagina+1
            #propsArray << JSON.parse(res)["dados"]
            res = RestClient.get("#{API_URL}/deputados?idLegislatura=55&siglaUf=PE&ordem=ASC&ordenarPor=nome&pagina=#{pagina}")
            res = JSON.parse(res)
            res["dados"].each do |d|	
                propsArray << d
            end
        end

        # Para cada proposição (PL), detalhar com outra requisição e verificar se 'siglaOrgao' corresponde a alguma sigla do array siglasComissoesArray
        # Caso pertença, contamos +1 PL para est@ dept no ano em questão. Caso negativo, não contamos.

        dept_prop_count = 0

        propsArray.each do |prop|
            # prop_detalhada = GET "#{API_URL}/proposicoes/prop['id']"
            res = RestClient.get("#{API_URL}/proposicoes/#{prop['id']}")
            prop_detalhada = JSON.parse(res)["dados"]

            if(siglasComissoesArray.include? prop_detalhada['statusProposicao']['siglaOrgao'])
                dept_prop_count += 1
                logger.info("Correspondencia Encontrada. Detalhes:")
                logger.info("Ano: #{ano}")
                logger.info("Deputado: #{dept['nome']}")
                logger.info("PL: #{API_URL}/proposicoes/#{prop['id']}")
                logger.info("Enviado para Comissão: #{prop_detalhada['statusProposicao']['siglaOrgao']}")
                logger.info("============================================================================================")
            end
        end

        dept_info_hash["prop#{ano%2000}"] = dept_prop_count
        dept_prop_count = 0
    end

    puts "#{dept_info_hash['nome']}, #{dept_info_hash['prop15']}, #{dept_info_hash['prop16']}, #{dept_info_hash['prop17']}, #{dept_info_hash['prop18']}"
end