defmodule TspTest do
  use ExUnit.Case
  doctest Tsp

  test "The initial population can calculate its distance" do
    population =
      Population.new(35)
      |> GeneticAlgorithm.evaluate

    assert population |> length == 35
    assert Population.calculate_distance(population) == 1657.5738695563828
  end

end
