"""
Q6: Real-World Driver Positioning System
Section C, Q6
Pre-position exactly 10 drivers across a 6x6 grid (36 zones) to maximise: sum(demands[i] for i in placed) - 5 * 10
"""

import random

DEMANDS = [
    12, 45, 23, 67, 34, 19,
    56, 38, 72, 15, 49, 61,
    27, 83, 41, 55, 30, 77,
    64, 18, 52, 39, 71, 26,
    44, 91, 33, 58, 22, 85,
    16, 69, 47, 74, 31, 53
]
SUPPLY_PENALTY = 5
NUM_DRIVERS = 10
GRID_SIZE = 6 # 6x6 grid means zones are indexed 0 to 35, row-major order


# Q6(a): Problem Foundation

def state_fitness(state, demands):
    """Objective: sum of demands at placed zones minus supply penalty."""
    return sum(demands[z] for z in state) - SUPPLY_PENALTY * NUM_DRIVERS


def get_neighbours(state, demands):
    """
    Generates all neighbours by swapping one driver from a placed zone
    to any unoccupied zone.
    Each neighbour differs by exactly one zone substitution.
    Returns list of neighbour states (each a frozenset of 10 zones).
    """
    neighbours = []
    all_zones = set(range(len(demands)))
    unoccupied = all_zones - state
    for placed_zone in state:
        for empty_zone in unoccupied:
            neighbour = set(state)
            neighbour.remove(placed_zone)
            neighbour.add(empty_zone)
            neighbours.append(frozenset(neighbour))
    return neighbours


def random_state():
    """
    Generates a valid random initial state -> 10 unique zone indices
    sampled without replacement.
    Use random.sample()
    """
    return frozenset(random.sample(range(len(DEMANDS)), NUM_DRIVERS))


def test_foundation():
    """Q6(a): Print fitness of 3 random states and verify neighbour counts."""
    print("=" * 65)
    print("Q6(a): Problem Foundation Tests")
    print("=" * 65)
    print(f"\n  {'Trial':<8} {'Zones (sorted)':<38} {'Fitness':>8} {'Neighbours':>12}")
    print("  " + "-" * 70)
    for i in range(3):
        state = random_state()
        fit = state_fitness(state, DEMANDS)
        neighbours = get_neighbours(state, DEMANDS)
        # Verify size and no duplicates
        for nb in neighbours:
            assert len(nb) == NUM_DRIVERS
            assert len(nb) == len(set(nb))
        print(f"  {i+1:<8} {str(sorted(list(state))):<38} {fit:>8} {len(neighbours):>12}")
    print(f"\n  Verification: all neighbours have size={NUM_DRIVERS}, no duplicates. PASSED")
    # Verify expected neighbour count: 10 drivers can move to any of the 26 unoccupied zones
    state = random_state()
    nb = get_neighbours(state, DEMANDS)
    print(f"  Expected neighbours: {NUM_DRIVERS} x {36 - NUM_DRIVERS} = "
          f"{NUM_DRIVERS * (36 - NUM_DRIVERS)}")
    print(f"  Actual neighbours:   {len(nb)}")


# Q6(b): Random Restart HC System

def hc_driver(state, demands, variant):
    """
    Single HC run supporting 'first_choice' and 'stochastic' variants.
    Returns (final_state, final_fitness, steps).
    """
    current_state = frozenset(state)
    current_fitness = state_fitness(current_state, demands)
    steps = 0

    while True:
        neighbours = get_neighbours(current_state, demands)

        if variant == 'first_choice':
            # Explore neighbours in order, move to first better one found.
            moved = False
            for nb in neighbours:
                if state_fitness(nb, demands) > current_fitness:
                    current_state = nb
                    current_fitness = state_fitness(nb, demands)
                    steps += 1; moved = True; break
            if not moved:
                break

        else:  # stochastic: collect all better neighbours, pick one at random to move to.
            uphill = [nb for nb in neighbours
                      if state_fitness(nb, demands) > current_fitness]
            if not uphill:
                break
            current_state = random.choice(uphill)
            current_fitness = state_fitness(current_state, demands)
            steps += 1

    return (current_state, current_fitness, steps)


def rrhc_driver(num_restarts, demands, variant):
    """
    RRHC: runs num_restarts HC runs from random starts.
    Returns (best_state, best_fitness, per_restart_fitness_list).
    """
    best_state = None
    best_fitness = -1
    per_restart = []

    for _ in range(num_restarts):
        start = random_state()
        final_state, final_fitness, _ = hc_driver(start, demands, variant)
        per_restart.append(final_fitness)
        if final_fitness > best_fitness:
            best_fitness = final_fitness
            best_state = final_state

    return (best_state, best_fitness, per_restart)


def zone_to_rowcol(zone):
    """Convert flat zone index to (row, col) in the 6x6 grid."""
    return (zone // GRID_SIZE, zone % GRID_SIZE)


def run_rrhc():
    """Q6(b): Run RRHC with 30 restarts and print results."""
    print("\n" + "=" * 65)
    print("Q6(b): RRHC: 30 restarts, Stochastic HC")
    print("=" * 65)

    best_state, best_fitness, per_restart = rrhc_driver(30, DEMANDS, 'stochastic')

    print(f"\n  Best fitness: {best_fitness}")
    print(f"  Best zones:   {sorted(list(best_state))}")
    print(f"\n  Driver zone assignments:")
    for zone in sorted(list(best_state)):
        row, col = zone_to_rowcol(zone)
        print(f"    Zone {zone:>2}: (row={row}, col={col})  demand={DEMANDS[zone]}")
    print(f"\n  Per-restart fitness: {per_restart}")

    return best_state, best_fitness


# Q6(c): Genetic Algorithm System

def ga_fitness(chromosome, demands):
    """Same objective as state_fitness but accepts a sorted list."""
    return sum(demands[z] for z in chromosome) - SUPPLY_PENALTY * NUM_DRIVERS


def ordered_crossover(p1, p2):
    """
    Order Crossover (OX): copy slice from p1, fill remaining from p2 in order skipping duplicates. Preserves uniqueness constraint.
    """
    n = len(p1)

    # Randomly select crossover points (start < end)
    start = random.randint(0, n - 1)
    end = random.randint(start + 1, n)

    # Create child with None, copy slice from p1
    child = [None] * n
    child[start:end] = p1[start:end]
    slice_set = set(p1[start:end])

    # Fill remaining positions with genes from p2 in order, skipping those in the slice
    p2_filtered = [x for x in p2 if x not in slice_set]
    fill_positions = [i for i in range(n) if child[i] is None]
    for i, pos in enumerate(fill_positions):
        child[pos] = p2_filtered[i]

    return sorted(child) # Return sorted to maintain consistency with state representation (sorted list of zones)


def ga_mutate(chromosome, p_m):
    """
    With probability p_m, swap one randomly chosen zone in the chromosome
    with a randomly chosen zone NOT in the chromosome.
    """
    if random.random() < p_m:
        in_chrom = set(chromosome)
        not_in = list(set(range(len(DEMANDS))) - in_chrom)
        if not not_in:
            return chromosome[:]
        # Randomly select one zone to remove and one to add
        remove_zone = random.choice(chromosome)
        add_zone = random.choice(not_in)
        new_chrom = [z for z in chromosome if z != remove_zone]
        new_chrom.append(add_zone)
        return sorted(new_chrom)
    return chromosome[:]


def tournament_select_ga(population, demands, tournament_size=3):
    """Tournament selection: pick tournament_size individuals, return fittest."""
    competitors = random.sample(population, tournament_size)
    return max(competitors, key=lambda c: ga_fitness(c, demands))


def run_driver_ga(pop_size, generations, p_m, demands):
    """
    Full GA for driver positioning with tournament selection (size=3).
    Returns (best_chromosome, best_fitness).
    """

    # Initialize population with random chromosomes (sorted lists of 10 unique zones)
    population = [sorted(random.sample(range(len(demands)), NUM_DRIVERS)) 
                  for _ in range(pop_size)]
    best_chrom_overall = None
    best_fit_overall = -1

    for _ in range(1, generations + 1):
        for chrom in population:
            f = ga_fitness(chrom, demands)
            if f > best_fit_overall:
                best_fit_overall = f; best_chrom_overall = chrom[:]

        # Create next generation
        next_population = []
        while len(next_population) < pop_size:
            p1 = tournament_select_ga(population, demands, 3)
            p2 = tournament_select_ga(population, demands, 3)
            offspring = ordered_crossover(p1, p2)
            offspring = ga_mutate(offspring, p_m)
            next_population.append(offspring)
        population = next_population

    return (best_chrom_overall, best_fit_overall)


def run_ga_section():
    """Q6(c): Run GA and print results."""
    print("\n" + "=" * 65)
    print("Q6(c): GA: pop=30, gen=100, p_m=0.1")
    print("=" * 65)
    best_chrom, best_fit = run_driver_ga(30, 100, 0.1, DEMANDS)
    print(f"\n  Best fitness: {best_fit}")
    print(f"  Best zones:   {best_chrom}")
    print(f"\n  Driver zone assignments:")
    for zone in best_chrom:
        row, col = zone_to_rowcol(zone)
        print(f"    Zone {zone:>2}: (row={row}, col={col})  demand={DEMANDS[zone]}")
    return best_chrom, best_fit


# Q6(d): Head-to-Head Comparison
# Run both 20 independent times, record best fitness per trial, report mean, std, best single run for each algorithm.

def compute_mean(values):
    return sum(values) / len(values)


def compute_std(values):
    mean = compute_mean(values)
    return (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5


def head_to_head():
    """Q6(d): 20 independent trials each, then structured analysis."""
    print("\n" + "=" * 65)
    print("Q6(d): Head-to-Head: RRHC vs GA (20 independent trials each)")
    print("=" * 65)

    TRIALS = 20
    rrhc_results = []
    ga_results = []

    print("  Running 20 RRHC trials...")
    for _ in range(TRIALS):
        _, fit, _ = rrhc_driver(30, DEMANDS, 'stochastic')
        rrhc_results.append(fit)

    print("  Running 20 GA trials...")
    for _ in range(TRIALS):
        _, fit = run_driver_ga(30, 100, 0.1, DEMANDS)
        ga_results.append(fit)

    print(f"\n  {'Algorithm':<12} {'Mean':>10} {'Std Dev':>10} {'Best':>10}")
    print("  " + "-" * 46)
    print(f"  {'RRHC':<12} {compute_mean(rrhc_results):>10.2f} "
          f"{compute_std(rrhc_results):>10.2f} {max(rrhc_results):>10}")
    print(f"  {'GA':<12} {compute_mean(ga_results):>10.2f} "
          f"{compute_std(ga_results):>10.2f} {max(ga_results):>10}")


# Entry point
if __name__ == "__main__":
    test_foundation()
    run_rrhc()
    run_ga_section()
    head_to_head()
