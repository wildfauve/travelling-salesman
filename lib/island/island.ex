defmodule Tsp.Island do
  require Logger

  @moduledoc """
  The main module for the Island model algorithm

  Each island process works on its own population to find the solution specified by
  the minimum distance value. Occasionally (see Migration Gap) an island's best candidates
  are migrated between neighbouring islands.
  When an island finds a solution with the required fitness value it informs the master
  process, which in turn reports the solution and cleans up the remaining resources.
  """

  @min_distance 900
  @population_size 60
  @crossover_rate 0.95
  @mutation_rate 0.001
  @elitism_count 3
  @tournament_size 5
  @migration_gap 10


  def get_log_params do
    "Distance: #{@min_distance} Population: #{@population_size}, Crossover #{@crossover_rate}, " <>
      "Mutation: #{@mutation_rate}, Elitism: #{@elitism_count}, Tournament: #{@tournament_size}, " <>
      "Migration: #{@migration_gap}"
  end

  @doc """
  The master process for the Island model.

  Spawns and initialisses the worker processes then waits until a worker
  reports that it has found a suitable candidate solution.
  """
  def run(num_workers) do
    pool = Cluster.create_worker_pool(num_workers, &start_worker/0)

    # initialise each worker
    for worker <- pool do
      send worker, {:workers, pool, self()}
    end

    # Wait for the first worker to send the final solution
    receive do
      {:distance, distance, generation} ->
        Logger.info("Test completed after #{generation} generations")
        IO.puts("Complete at generation: #{generation}, distance: #{distance}")
    end

    # Clean up resources
    _ = pool |> Enum.map(fn pid -> Process.exit(pid, :kill) end)
    Utilities.flush()  # Clear out any duplicate solutions
  end


  # Waits for the worker pool from the master process, and from this
  # calculates this process' neighbours list. Also returns the master
  # pid.
  def find_neighbours() do
    receive do
      {:workers, worker_pool, from} ->
        neighbours = calculate_neighbours(worker_pool)
        {from, neighbours}
    end
  end


  # Starts the worker process
  defp start_worker() do
    {master, neighbours} = find_neighbours()

    population =
      @population_size
      |> Population.new
      |> GeneticAlgorithm.evaluate()

    distance = Population.calculate_distance(population)
    process_population(population, {master, neighbours}, 1, distance)
  end

  # Replies to master process when a suitable solution has been found
  def process_population(_population, {master, _neighbours}, generation, distance)
  when (@min_distance >= distance) do
    send master, {:distance, distance, generation}
  end


  # Perform crossover and mutation of a population
  def process_population(population, {_, neighbours} = pool, generation, _distance) do

    # split elite and non-elite individuals based on fitness value
    sorted_population =
    {elite_population, _common_population} =
      population
      |> Population.sort
      |> Enum.split(@elitism_count)

    general_population =
      sorted_population
      |> GeneticAlgorithm.crossover(@population_size, @crossover_rate, @tournament_size)
      |> GeneticAlgorithm.mutate_optimised(@mutation_rate)

    migrated_population =
    if (rem generation, @migration_gap) == 0 do
      send_elites(neighbours, elite_population)

      neighbours
      |> length
      |> await_elites
      |> integrate(general_population)
    else
      general_population
    end

    # update population fitness
    new_population =
      elite_population ++ migrated_population
      |> GeneticAlgorithm.evaluate

    new_distance = Population.calculate_distance(new_population)

    process_population(new_population, pool, generation + 1, new_distance)
  end


  # Sends elite members to neighbouring worker processes
  def send_elites(neighbours, elites) do
    for neighbour <- neighbours, do:
      send neighbour, {self(), elites: elites}
  end

  # Merges the new elite population into the general population.
  # Some members are randomly dropped to maintain constant population size.
  def integrate(elites, population) when is_list(population) do
    elites ++ population
    |> Enum.shuffle
    |> Enum.take(length(population))
  end

  # Waits for response messages from neighbour processes
  # which are added to the population.
  def await_elites(count, population \\ [])
  def await_elites(0, population), do: population
  def await_elites(count, population) when count > 0 do
    receive do
      {_from, elites: elites} when is_list(elites) ->
        await_elites(count - 1, elites ++ population)
    end
  end

  @doc """
  Returns the neighbouring process pids.

  Given an ordered list of pids the neighbours are the ones
  immediately before and after the current pid.
  """
  def calculate_neighbours(workers) when is_list(workers) do
    # find current pid index in list of worker pids
    index = Enum.find_index(workers, &(&1 == self()))

    len = length(workers)
    previous = rem (index - 1) + len, len
    next = rem (index + 1), len
    case len do
      1 -> []
      2 ->
        [workers |> Enum.at(next)]
      _ ->
        [workers |> Enum.at(previous), workers |> Enum.at(next)]
    end
  end

end
