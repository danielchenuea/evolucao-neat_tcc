-- Daniel Akio Chen - UEA/EST
-- Código relacionado ao treinamento de neuroevolução para conclusão de jogos
-- Deve ser usado junto do emulador BizHawk(Emulador que consegue executar scripts Lua)
 

Filename = "3SMB1-1.state"
ButtonNames = {
	"A",
	"B",
	"Up",
	"Down",
	"Left",
	"Right",
}


BoxRadius = 6
InputSize = 169

Inputs = 170
Outputs = 6

Population = 300
CoefDisjunto = 2.0
CoefWeights = 1.0
CoefLimite = 1.0

StaleSpecies = 15
TempoTimeout = 30

MutateWeigthChance = 0.4
CruzamentoChance = 0.9
AddLinkChance = 1.8
AddNodeChance = 0.4
AddBiasChance = 0.35
DisableMutationChance = 0.3
EnableMutationChance = 0.15
StepChance = 0.80
StepSize = 0.1

ControllerPontos = 1
EnemiesPontos = 3

MaxNodes = 1000000

function getPositions()
	-- Posição do jogador, x e y
	-- 0x86 0-255 posição x na tela
	-- 0x6D quantidade de vezes que 0-255 rola a tela
	-- Juntos, eles formam a posição x
	marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte(0x86)
	marioY = memory.readbyte(0x03B8)+16

	-- Posição x e y da tela 
	screenX = memory.readbyte(0x03AD)
	screenY = memory.readbyte(0x03B8)
end
 
function getTile(dx, dy)

	local x = marioX + dx + 8 -- Meio do tile
	local y = marioY + dy - 16 -- Encima de um tile
	local page = math.floor(x/256)%2

	local subx = math.floor((x%256)/16) -- divide em tiles da pagina
	local suby = math.floor((y - 32)/16)
	local addr = 0x500 + page*13*16+suby*16+subx

	if suby >= 13 or suby < 0 then -- 0 a 256 pixels
		return 0
	end

	if memory.readbyte(addr) ~= 0 then
		return 1
	else
		return 0
	end

end
 
function getEnemies()
	local sprites = {}
	for inimigo=0,4 do
		local enemy = memory.readbyte(0xF+inimigo) -- 0x000F-0x0013 Conta os inimigos na tela
		if enemy == 1 then
			-- Igual o mario:
			-- 0x87 0-255 posição x na tela. Ele contem 5 espaços pq pode conter 5 inimigos na tela
			-- 0x6E quantidade de vezes que 0-255 rola a tela. 
			local ex = memory.readbyte(0x6E + inimigo)*0x100 + memory.readbyte(0x87+inimigo)
			local ey = memory.readbyte(0xCF + inimigo)+24

			sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
		end
	end

	return sprites
end
 
function getInputs()
	getPositions()
 
	sprites = getEnemies()
 
	local inputs = {}
	-- 1 bloco do mario tem 16x16
	for dy=-BoxRadius*16,BoxRadius*16,16 do
		for dx=-BoxRadius*16,BoxRadius*16,16 do
			inputs[#inputs+1] = 0
 
			tile = getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
 
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = -1
				end
			end

		end
	end
 
	return inputs
end

-- Função Sigmoide, coloca as funções entre 0 e 1
-- Nesse caso, as funções ficam entre -1 e 1
function sigmoid(x)
	return 2/(1+math.exp(-4.9*x))-1
end

-- Geração de um teste novo, com população geração etc
function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	pool.maxDifficulty = 0
 
	return pool
end

-- Nova especie
function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
 
	return species
end

-- Novo individuo 
function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0

	genome.n_enemies = 0
	genome.n_buttons = 0
	genome.completionTime = 0
	genome.difficulty_measurement = 0

	genome.mutationRates = {}
	genome.mutationRates["connections"] = MutateWeigthChance
	genome.mutationRates["link"] = AddLinkChance
	genome.mutationRates["bias"] = AddBiasChance
	genome.mutationRates["node"] = AddNodeChance
	genome.mutationRates["enable"] = EnableMutationChance
	genome.mutationRates["disable"] = DisableMutationChance
	genome.mutationRates["step"] = StepSize
 
	return genome
end
 
--Copia do indivudo
function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
 
	return genome2
end
 
-- Individuo basico
function basicGenome()
	local genome = newGenome()
	genome.maxneuron = Inputs
	mutate_master(genome)
	return genome
end
 
-- Criar nova conexão
function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
 
	return gene
end
 
--Copiar conexão
function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
 
	return gene2
end

-- Adicionar novo neuronio para a avaliação de rede 
function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
 
	return neuron
end

-- gerar rede utilizada para avaliação
function generateRede(genome)
	local network = {}
	network.neurons = {}
 
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
 
	for o=1,Outputs do
		network.neurons[MaxNodes+o] = newNeuron()
	end
  -- Sort por saidas
	table.sort(genome.genes, function (a,b) return (a.out < b.out) end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
 
	genome.network = network
end

-- Avaliar a rede para sair um controle
function evaluateNetwork(network, inputs)
	table.insert(inputs, 1) -- bias
 
	for i=1,Inputs do
		network.neurons[i].value = inputs[i]
	end
 
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
 
		if #neuron.incoming > 0 then
			neuron.value = sigmoid(sum)
		end
	end
 
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. ButtonNames[o]
		if network.neurons[MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
 
	return outputs
end

-- Cruzamento entre individuos
function crossover(g1, g2)
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end
 
	local child = newGenome()
 
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
 
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then -- Aleatorio para decidir qual copiar
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
 
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
 
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
 
	return child
end

-- Escolher uma conexão aleatória, pode ser input ou não input
function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end
	for o=1,Outputs do
		neurons[MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)

	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
 
	return 0
end

-- Verificar se existe um link para mutação
function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

-- Mutar os pesos da rede
function mutatePeso(genome) 
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < StepChance then
			gene.weight = gene.weight + (math.random() * genome.mutationRates["step"] * 2) - genome.mutationRates["step"]
		else
			gene.weight = math.random() * 4 - 2
		end
	end
end

-- Adicionar um link aleatorio a rede
function mutateLink(genome)
	local neuron1 = randomNeuron(genome.genes, false)
	local neuron2 = randomNeuron(genome.genes, true)
 
	local newLink = newGene()
	if neuron1 <= Inputs and neuron2 <= Inputs then
		return
	end

	if neuron2 <= Inputs then
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end
 
	newLink.into = neuron1
	newLink.out = neuron2
 
	if containsLink(genome.genes, newLink) then
		return
	end

	pool.innovation = pool.innovation + 1
	newLink.innovation = pool.innovation
	newLink.weight = math.random()*4-2
 
	table.insert(genome.genes, newLink)
end

-- Adicionar uma conexão ao bias
function mutateBias(genome)
	local neuron = randomNeuron(genome.genes, true)
	local newLink = newGene()

	newLink.into = Inputs
	newLink.out = neuron

	if containsLink(genome.genes, newLink) then
		return
	end

	pool.innovation = pool.innovation + 1
	newLink.innovation = pool.innovation
	newLink.weight = math.random()*4-2
 
	table.insert(genome.genes, newLink)
end
 
-- Mutar de adicionar um neuronio
function mutateNode(genome)
	if #genome.genes == 0 then
		return
	end
 
	genome.maxneuron = genome.maxneuron + 1
 
	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
 
	addNeuron(genome, gene)
end

-- Mutar um link na rede, retirar uma conexão, adicionar um neuronio e duas conexões
function addNeuron(genome, gene)
 
	local gene1 = newGene()
	gene1.into = gene.into
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	pool.innovation = pool.innovation + 1
	gene1.innovation = pool.innovation
	gene1.enabled = true
	table.insert(genome.genes, gene1)
 
	local gene2 = newGene()
	gene2.into = genome.maxneuron
	gene2.out = gene.out
	gene2.weight = gene.weight
	pool.innovation = pool.innovation + 1
	gene2.innovation = pool.innovation
	gene2.enabled = true
	table.insert(genome.genes, gene2)

	gene.enabled = false
end

-- Mutação, habilitar nó
function enableMutate(genome)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == false then
			table.insert(candidates, gene)
		end
	end
	if #candidates == 0 then return end
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = true
end

-- mutação ,desabilitar nó
function disableMutate(genome)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == true then
			table.insert(candidates, gene)
		end
	end
	if #candidates == 0 then return end
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = false
end

-- Reune todas as funções de mutação em 1
function mutate_master(genome)
 
	if math.random() < genome.mutationRates["connections"] then
		mutatePeso(genome)
	end
 
  -- garante que o link possa ser adicionado duas vezes
	local chance = genome.mutationRates["link"]
	while chance > 0 do
		if math.random() < chance then
			mutateLink(genome)
		end
		chance = chance - 1
	end
 
	if math.random() < genome.mutationRates["bias"] then
		mutateBias(genome)
	end
 
	if math.random() < genome.mutationRates["node"] then
		mutateNode(genome)
	end
 
	if math.random() < genome.mutationRates["enable"] then
		enableMutate(genome)
	end
 
	if math.random() < genome.mutationRates["disable"] then
		disableMutate(genome)
	end
end
 
-- Verificar os genes disjuntos dentre dois individuos
function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end
 
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
 
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
 
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
 
	local n = math.max(#genes1, #genes2)
 
	return disjointGenes / n
end

-- Verifica a coincidencia de pesos entre dois individuos
function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end
 
	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
 
	return sum / coincident
end

-- Baseado na disjunção e peso, verificar se eles são da mesma especia
-- Threshold logic
function mesmaEspecie(genome1, genome2)
	local dis = CoefDisjunto*disjoint(genome1.genes, genome2.genes)
	local pes = CoefWeights*weights(genome1.genes, genome2.genes)
	return dis + pes < CoefLimite
end
 
-- Ranquear os individuos baseado no desempenho
function rankGlobally()
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b) return (a.fitness < b.fitness) end)
 
	for g=1,#global do
		global[g].globalRank = g
	end
end
 
-- Calcular o fitness medio
function calculateAverageFitness(species)
	local total = 0
 
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
 
	species.averageFitness = total / #species.genomes
end
 
-- calcular o total de fitness, serve pra logica de remoção de especies
function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end
 
	return total
end

-- Decide quantas especies serão removidas
function removerSpecies(sobrar1)
	for s = 1,#pool.species do
		local species = pool.species[s]
 
		table.sort(species.genomes, function (a,b) return (a.fitness > b.fitness) end)
 
		local remaining = math.ceil(#species.genomes/2)
		if sobrar1 then
			remaining = 1
		end

		while #species.genomes > remaining do
			table.remove(species.genomes)
		end

	end
end

-- Cruzar duas especies e gerar uma prole
function breedChild(species)
	local child = {}
	if math.random() < CruzamentoChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
 
	mutate_master(child)
 
	return child
end

-- Remover especies que não foram modificado por muito tempo
function removeStale()
	local survived = {}
 
	for s = 1,#pool.species do
		local species = pool.species[s]
 
		table.sort(species.genomes, function (a,b) return (a.fitness > b.fitness) end)
 
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end
 
	pool.species = survived
end

-- Filtrar especies baseado no fitness apresentado
function removerSpeciesFitness()
	local survived = {}
 
	local sum = totalAverageFitness()
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end
 
	pool.species = survived
end

-- Dividir individuos em especies
function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if foundSpecies == false and mesmaEspecie(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
 
	if foundSpecies == false then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

-- Inicializar o treinmanento
function initializeRun()
	savestate.load(Filename);
	rightmost = 0
	pool.currentFrame = 0
	timeout = TempoTimeout
	clearController()
 
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	generateRede(genome)
	avaliarAtual()
end

-- Avaliar a rede, determinar os botões pressionados e jogar no controle
function avaliarAtual()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
 
	inputs = getInputs()
  -- Avaliar a rede
	controller = evaluateNetwork(genome.network, inputs)
 
  -- Impede movimentos nulos
	if controller["P1 Left"] == controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] == controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

  -- Colocar resultado no controle
	joypad.set(controller)
end

-- resetar controle
function clearController()
	controller = {}
	controller["P1 A"] = false
	controller["P1 B"] = false
	controller["P1 Up"] = false
	controller["P1 Down"] = false
	controller["P1 Left"] = false
	controller["P1 Right"] = false

	joypad.set(controller)
end

-- Contar os botões pressionados atualmente
function countController()
	local counter = 0
	if controller["P1 A"] == true then
		counter = counter + ControllerPontos
	end
	if controller["P1 B"] == true then
		counter = counter + ControllerPontos
	end
	if controller["P1 Right"] == true then
		counter = counter + ControllerPontos
	end
	if controller["P1 Left"] == true then
		counter = counter + ControllerPontos
	end
	if controller["P1 Up"] == true then
		counter = counter + ControllerPontos
	end
	if controller["P1 Down"] == true then
		counter = counter + ControllerPontos
	end
	return counter
end

-- Contar os inimigos presentes
function countEnemies()
	local counter = 0
	for inimigo=0,4 do
		local enemy = memory.readbyte(0xF+inimigo) -- 0x000F-0x0013 Conta os inimigos na tela
		if enemy == 1 then
			counter = counter + EnemiesPontos
		end
	end
	return counter
end

-- Passar para o proximo individuo
function proximoGenoma()
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies + 1
		if pool.currentSpecies > #pool.species then
      pool.currentSpecies = 1
			novaGeneration()
		end
	end
end

-- Começar uma nova geração de especies
function novaGeneration()
	removerSpecies(false)
	-- rankGlobally()
	removeStale()
	rankGlobally()
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removerSpeciesFitness()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	removerSpecies(true) -- Deixar apenas a especie mais fitness de cada especie
	while #children + #pool.species < Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
 
	pool.generation = pool.generation + 1
 
	salvarFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
end

-- Verificar se ja foi medido o desempenho
function fitnessMedido()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
 
	return genome.fitness ~= 0 -- Se já for medido, False
end

-- Função principal pra mostrar a rede
function displayRede(genome)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	for dy=0,BoxRadius*2 do -- Desenhar as caixas do mapa/Entradas
		for dx=0,BoxRadius*2 do
			cell = {}
			cell.x = 170+5*dx 	-- 20
			cell.y = 40+5*dy	-- 40
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end

	-- desenhar a caixa
	gui.drawBox(200-BoxRadius*5-3,70-BoxRadius*5-3,200+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)

	local biasCell = {} -- bias
	biasCell.x = 240
	biasCell.y = 100
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell

	for o = 1, 2 do --outputs
		cell = {}
		cell.x = 170 + 8 * o
		cell.y = 205
		cell.value = network.neurons[MaxNodes + o].value
		cells[MaxNodes+o] = cell
		gui.drawText(164 + 9 * o, 209, ButtonNames[o], 0xFF000000, 9)
	end

	-- UP
	cell = {}
	cell.x = 224
	cell.y = 195
	cell.value = network.neurons[MaxNodes + 3].value
	cells[MaxNodes + 3] = cell

	-- DOWN
	cell = {}
	cell.x = 224
	cell.y = 215
	cell.value = network.neurons[MaxNodes + 4].value
	cells[MaxNodes + 4] = cell

	-- LEFT
	cell = {}
	cell.x = 214
	cell.y = 205
	cell.value = network.neurons[MaxNodes + 5].value
	cells[MaxNodes + 5] = cell

	-- RIGHT
	cell = {}
	cell.x = 234
	cell.y = 205
	cell.value = network.neurons[MaxNodes + 6].value
	cells[MaxNodes + 6] = cell

	for n,neuron in pairs(network.neurons) do -- neuronios escondidos
		cell = {}
		if n > Inputs and n <= MaxNodes then
			cell.x = 202
			cell.y = 152
			cell.value = neuron.value
			cells[n] = cell
		end
	end

	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			calculateNewPosition(cells, gene)
		end
	end
	
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then

			local opacity = 0xFF000000 -- Opacidade 255 / Preto
			local color
			if cell.value == 0 then
				opacity = 0x50000000
			end
			if cell.value >= 0 and n <= MaxNodes then
				color = opacity + 0xFFFFFF
			end
			if cell.value >= 0 and n > MaxNodes then
				color = opacity + 0x00A0FF
			end
			if cell.value < 0 and n <= MaxNodes then
				color = opacity + 0x000000
			end
			if cell.value < 0 and n > MaxNodes then
				color = opacity + 0x0000FF
			end

			gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end

	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0x0
			if c1.value == 0 then
				opacity = 0x20000000
			else
				opacity = 0xA0000000
			end
			if gene.weight > 0 then 
				color = opacity + 0x008000 -- verde
			else
				color = opacity + 0x800000 -- vermelho
			end
			gui.drawLine(c1.x, c1.y, c2.x, c2.y, color)
		end
	end
end

-- Calcular posição de neuronio no mapa
function calculateNewPosition(cells, gene)
	local cell_in = cells[gene.into]
	local cell_out = cells[gene.out]
	if gene.into > Inputs and gene.into <= MaxNodes then -- Se os nós de entrada forem escondidos
		cell_in.y = 0.6*cell_in.y + 0.4*cell_out.y
		if cell_in.y >= cell_out.y then
			cell_in.y = cell_in.y - 40
		end
		if cell_in.y < 110 then cell_in.y = 120 end
		if cell_in.y > 190 then cell_in.y = 180 end
		cell_in.x = 0.6*cell_in.x + 0.4*cell_out.x

	end
	if gene.out > Inputs and gene.out <= MaxNodes then -- Se os nós de saida forem escondidos
		cell_out.y = 0.4*cell_in.y + 0.6*cell_out.y
		if cell_in.y >= cell_out.y then
			cell_out.y = cell_out.y + 40
		end
		if cell_out.y < 110 then cell_out.y = 120 end
		if cell_out.y > 190 then cell_out.y = 180 end

		cell_out.x = 0.4*cell_in.x + 0.6*cell_out.x
	end
end

-- Salvar o arquivo com o treinamento
function salvarFile(filename)

  local file = io.open(filename, "w")

  -- Informações do treinamento
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(#pool.species .. "\n")

  -- Salvar todas as espécies
  for n,species in pairs(pool.species) do
		file:write(species.topFitness .. "\n")
		file:write(species.staleness .. "\n")
		file:write(#species.genomes .. "\n")

    -- Das espécies, salvar os individuos
		for m,genome in pairs(species.genomes) do
			file:write(genome.fitness .. "\n")
			file:write(genome.maxneuron .. "\n")
			for mutation,rate in pairs(genome.mutationRates) do
				file:write(mutation .. "\n")
				file:write(rate .. "\n")
			end
			file:write("done\n")
 
			file:write(#genome.genes .. "\n")
      -- Além disso, salvar as conexões dos individuos
			for l,gene in pairs(genome.genes) do
				file:write(gene.into .. " ")
				file:write(gene.out .. " ")
				file:write(gene.weight .. " ")
				file:write(gene.innovation .. " ")
				if(gene.enabled) then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end

		end
        end
        file:close()
end

-- Carregar um arquivo da população
function carregarFile(filename)

  local file = io.open(filename, "r")

  -- Carregar o treinamento
	pool = newPool()
	pool.generation = file:read("*number")
	pool.maxFitness = file:read("*number")
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
  local numSpecies = file:read("*number")

  -- Carregar o numero de especies presentes no treinamento
  for s=1,numSpecies do
		local species = newSpecies()
		table.insert(pool.species, species)
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		local numGenomes = file:read("*number")

    -- Carregar o numero de individuos em cada especie
		for g=1,numGenomes do
			local genome = newGenome()
			table.insert(species.genomes, genome)
			genome.fitness = file:read("*number")
			genome.maxneuron = file:read("*number")
			local line = file:read("*line")

			while line ~= "done" do
				genome.mutationRates[line] = file:read("*number")
				line = file:read("*line")
			end
			local numGenes = file:read("*number")

      -- Carregar as conexões de cada individuo
			for n=1,numGenes do
				local gene = newGene()
				table.insert(genome.genes, gene)
				local enabled
				gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
				if enabled == 0 then
					gene.enabled = false
				else
					gene.enabled = true
				end
 
			end
		end
	end
        file:close()
 
  -- Procurar o individuo a ser testado
	while fitnessMedido() do
		proximoGenoma()
	end
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end

-- Salvar o treinamento atual
function salvarPool()
	local filename = forms.gettext(saveLoadFile)
	salvarFile(filename)
end

-- Carregar o treinamento atual
function carregarPool()
	local filename = forms.gettext(saveLoadFile)
	carregarFile(filename)
end

-- Carregar melhor rede
function carregarTop()
	local maxfitness = 0
	local maxs, maxg
  -- Procurar a rede
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
  -- Carregar
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end

-- Quando sair
function onExit()
	forms.destroy(form)
end

-- Inicializar treinamento
function initializePool()
	pool = newPool()
 
	for i=1,Population do
		addToSpecies(basicGenome())
	end
 
	initializeRun()
end

-- Iniciar um treinamento se não houver nenhum
if pool == nil then
	initializePool()
end

-- ========== Botões =======================================================================================================================

salvarFile("temp.pool")
event.onexit(onExit)
form = forms.newform(300, 360, "Fitness")

saveLoadLabel = forms.label(form, "Salvar/Carregar:", 5, 8)
saveLoadFile = forms.textbox(form, Filename .. ".pool", 170, 25, nil, 5, 32)

showNetwork = forms.checkbox(form, "Esconder Mapa", 5, 52)
hideBanner = forms.checkbox(form, "Esconder Informações", 5, 74)


saveButton = forms.button(form, "Salvar", salvarPool, 5, 102)
loadButton = forms.button(form, "Carregar", carregarPool, 80, 102)
restartButton = forms.button(form, "Recomecar", initializePool, 5, 126)

playTopButton = forms.button(form, "Melhor", carregarTop, 5, 150)

maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 200)

-- ========== Lógica de execução =======================================================================================================================

while true do
 -- Pegar as especie e individuo atual
	local currentEspecies = pool.species[pool.currentSpecies]
	local currentGenoma = currentEspecies.genomes[pool.currentGenome]
 
  -- Mostrar a rede
	if not forms.ischecked(showNetwork) then
		displayRede(currentGenoma)
	end

	--Sem isso, as caixas nao funcionam
	gui.drawBox(197,71,203,78,0x00000000,0x80FF0000)

  -- Gera os comandos de controle a cada 5 frames
	if pool.currentFrame%5 == 0 then
		avaliarAtual()
	end

  -- Conta a quantidade de botões do controle a cada 12 frames
	if pool.currentFrame%12 == 0 then
		currentGenoma.n_buttons = currentGenoma.n_buttons + countController()
	end

  -- Conta a quantidade de inimigos na tela a cada 60 frames
	if pool.currentFrame%60 == 0 then
		currentGenoma.completionTime = currentGenoma.completionTime + 1
		currentGenoma.n_enemies = currentGenoma.n_enemies + countEnemies()
	end

  -- Pegar as informações x e y do jogador
	getPositions()

  -- Pegar a maior posição adquirida
	if marioX > rightmost then
		rightmost = marioX
		timeout = TempoTimeout
	end

  -- Lógica de timeout
	timeout = timeout - 1
	local timeoutBonus = pool.currentFrame / 4
	local fitness1 = math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3)

  -- Adicionar controle
	joypad.set(controller)

  -- Flags utilizados para morte ou término
	local playerDied = memory.readbyte(0x000E)
	local playerFell = memory.readbyte(0x00B5)
	local playerPole = memory.readbyte(0x001D)

	-- Se um empecilho ocorrer, verificar o fitness. Por ocorrer:
  -- Timeout
  -- Jogador morreu por inimigos
  -- Jogador ficou com fitness muito baixo (previne movimentos pequenos)
  -- Jogador morreu caindo
  -- Jogador tocou o final
	if timeout + timeoutBonus <= 0 or playerDied == 0x0B or fitness1 <= -200 or playerFell > 1 or playerPole == 0x03 then
		local fitness = rightmost - pool.currentFrame / 2

    -- Verifica se o empecilho foi tocar o final
		if rightmost > 3160 or playerPole == 0x03 then
			fitness = fitness + 1000
			console.writeline("Final fitness" .. currentGenoma.fitness)
		end

    -- Igual os fitness baixos
		if fitness <= 0 then
			fitness = -1
		end

    -- Caclula o fitness e a dificuldade
		currentGenoma.fitness = fitness
		currentGenoma.difficulty_measurement = currentGenoma.n_buttons*0.6 + currentGenoma.completionTime * 0.1 + currentGenoma.n_enemies * 0.2

    -- Se o fitness for maior que todos guardar
		if fitness > pool.maxFitness then
			pool.maxFitness = fitness
			pool.maxDifficulty = currentGenoma.n_buttons*0.6 + currentGenoma.completionTime * 0.1 + currentGenoma.n_enemies * 0.2
			forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
			salvarFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
		end

		console.writeline("Buttons " .. currentGenoma.n_buttons .. " Time " .. currentGenoma.completionTime .. " Enemies " .. currentGenoma.n_enemies)
		console.writeline("Difficulty " .. currentGenoma.difficulty_measurement)

    -- Próximo
		pool.currentSpecies = 1
		pool.currentGenome = 1
		while fitnessMedido() do
			proximoGenoma()
		end
		initializeRun()
	end

  -- Comando de uso do emulador, garante que o script está sendo feito em todo frame
	pool.currentFrame = pool.currentFrame + 1

  -- Mostrar as informações
	if not forms.ischecked(hideBanner) then
    local backgroundColor = 0xD0FFFFFF
		gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
		gui.drawText(0, 12, "Fitness: " .. fitness1, 0xFF000000, 11)
		gui.drawText(120, 12, "Max Fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
		gui.drawText(50, 0, "Dificuldade " .. currentGenoma.n_buttons*0.9 + currentGenoma.completionTime * 0.1, 0xFF000000, 11)
	end

	emu.frameadvance();
end 

-- 3161 ponto de chegada