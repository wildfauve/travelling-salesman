defmodule GeneticAlgorithm do

  @moduledoc """
  Contains the genetic operators for the Travelling Salesman problem
  """


  @doc """
  Creates the initial population of candidate solutions, each
  chromosome having the specified length.

    population_size     number of candidate solutions
    chromosome_length   length of chromosome
  """

  def initialise(population_size, chromosome_length) do
    Population.new(population_size, chromosome_length)
  end


  @doc """
  Evaluates true when generation count limit has been reached.
  """

  def terminateSearch?(count, limit), do: count > limit

  @doc """
  Calculates the fitness of a candidate solution.
  """

  def updateFitness(%Individual{chromosome: chromosome}=individual) do
    distance =
      chromosome
      |> Route.new
      |> Route.getDistance

    # short distances are fitter than long distances
    %Individual{individual | fitness:  1 / distance}
  end

  @doc """
  Updates the fitness for each pop
  """

def updateFitness(population) when is_map(population) do
  population
  |> Stream.map(fn {key, individual} ->
    {key, updateFitness(individual)}
  end) |> Enum.into(%{})
end

  @doc """
  Calculates the population average fitness.
  """

  def evaluate(population) when is_map(population) do
    population
    |> updateFitness
    |> Stream.map(fn {_, individual} ->
      individual.fitness
    end) |> Enum.sum
         |> Kernel./(map_size(population))
  end

  @doc """
  Select a parent from the population using tournament selection
  """

  def selectParent(population, tournamentSize) when tournamentSize > 0 do
    population
    |> Population.shuffle
    |> Enum.take(tournamentSize)
    |> Enum.into(%{})
    |> Population.getFittest
  end

  @doc """
  Applies the genetic crossover operator to two parents producing a
  single offspring.
  """

  def crossover(%Individual{chromosome: c1},
                %Individual{chromosome: c2}, start, finish) when start <= finish do

    chromosome_size = map_size(c1)
    offspring = Individual.offspring(chromosome_size)

    # Copy substring from first parent into offspring
    offspring.chromosome
    |> Enum.map(fn {key, value} ->
      if key in start..finish do
        {key, c1 |> Individual.getGene(key)}
      else
        {key, value}
      end
    end)

    # 0..chromosome_size-1
    # |> Enum.reduce(offspring.chromosome, fn key, acc ->
    #   IO.inspect(acc)
    #   parent2_key = rem(key + finish, chromosome_size)
    #   parent2_gene = c2 |> Individual.getGene(parent2_key)
    #
    #   unless acc |> Individual.containsGene?(parent2_gene) do
    #     # find the index of the first nil value
    #     offspring_index = acc |> Enum.find_index(fn {_k, v} -> v == nil end)
    #     # copy the missing value into offspring
    #     acc |> Individual.setGene(offspring_index, parent2_gene)
    #   else
    #     acc
    #   end
    # end)

  end

  @doc """
  The genetic operator crossover is applied to members of the population
  by selecting two parents which then reproduce to create a new offspring,
  containing genetic material from both parents.
  """

  def crossover(_population, _crossoverRate) do

  end

  @doc """
  Mutates members of the population according to the mutation rate.

  Note: the first n fittest members are allowed into the new population
  without mutation, where n = elitismCount.
  """

  def mutate(population, elitismCount, mutationRate) when is_map(population) do
    sorted_population = population |> Population.sort

    elite = sorted_population |> Stream.take(elitismCount) |> Enum.into(%{})

    non_elite =
      sorted_population
      |> Stream.drop(elitismCount)
      |> Stream.map(fn {key, ind} ->
        {key, ind |> Individual.mutate(mutationRate)}
      end) |> Enum.into(%{})

    Map.merge(elite, non_elite)
  end

end
