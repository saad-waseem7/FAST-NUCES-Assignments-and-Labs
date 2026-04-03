"""
Q4: Full Genetic Algorithm from Scratch
Section B, Q4
Target: maximise f(x) = -x^2 + 14x + 5, x in {0..15}
Representation: 4-bit binary chromosome
True maximum: x=7, f(7)=54
"""

import random


# Q4(a): Core GA Components

def decode(chromosome):
    """
    Converts a 4-bit binary list to an integer x.
    Reads bits left-to-right as most-significant to least-significant.
    """
    x = 0
    for bit in chromosome:
        x = x * 2 + bit
    return x


def fitness(chromosome):
    """
    Returns f(x) = -x^2 + 14x + 5 for the given chromosome.
    """
    x = decode(chromosome)
    return -x * x + 14 * x + 5


def roulette_select(population):
    """
    Selects one individual using fitness-proportionate (roulette wheel) selection.
    Must use random.random() for the spin.
    """
    total_fitness = sum(fitness(c) for c in population)
    spin = random.random() * total_fitness
    cumulative = 0
    for chrom in population:
        cumulative += fitness(chrom)
        if cumulative >= spin:
            return chrom
    return population[-1]


def single_point_crossover(parent1, parent2, point):
    """
    Returns two offspring after crossover at the given bit position.
    single_point_crossover(parent1, parent2, point) -> two offspring
    """
    offspring1 = parent1[:point] + parent2[point:]
    offspring2 = parent2[:point] + parent1[point:]
    return offspring1, offspring2


def mutate(chromosome, p_m):
    """
    Bit-flip mutation: each bit independently flipped with probability p_m.
    """
    return [1 - bit if random.random() < p_m else bit for bit in chromosome]


def test_core_functions():
    """Q4(a): Isolation tests for the four given chromosomes."""
    print("=" * 50)
    print("Q4(a): Core Function Tests")
    print("=" * 50)
    print(f"\n{'Chromosome':<20} {'x':>5} {'f(x)':>8}")
    print("-" * 36)
    for chrom in [[0,1,1,0], [1,0,0,1], [1,1,0,0], [0,0,1,1]]:
        print(f"{str(chrom):<20} {decode(chrom):>5} {fitness(chrom):>8}")

    print("\nCrossover test -> [0,1,1,0] x [1,0,0,1] at point 2:")
    o1, o2 = single_point_crossover([0,1,1,0], [1,0,0,1], 2)
    print(f"  O1={o1}  x={decode(o1)}  f={fitness(o1)}")
    print(f"  O2={o2}  x={decode(o2)}  f={fitness(o2)}")

    print("\nMutation test -> [0,1,1,0] with p_m=0.5:")
    random.seed(0)
    m = mutate([0,1,1,0], 0.5)
    print(f"  Original: [0,1,1,0]  x={decode([0,1,1,0])}  f={fitness([0,1,1,0])}")
    print(f"  Mutated:  {m}  x={decode(m)}  f={fitness(m)}")


# Q4(b): Full GA run with printing

def run_ga(pop_size, num_generations, p_m, elitism):
    """
    Full GA run with generation-by-generation printed table.
    Initialise random population, roulette select, crossover at random
    point, mutate, optional elitism. Returns list of (gen, best_fitness, best_x).
    """
    population = [[random.randint(0, 1) for _ in range(4)] for _ in range(pop_size)]
    history = []

    for gen in range(1, num_generations + 1):
        best_chrom = None
        best_fit = -1
        print(f"\nGeneration {gen}:")
        print(f"  {'Individual':<12} {'Chromosome':<20} {'x':>4} {'f(x)':>6}")
        print("  " + "-" * 46)

        for idx, chrom in enumerate(population):
            x = decode(chrom)
            f = fitness(chrom)
            print(f"  P{idx+1:<10} {str(chrom):<20} {x:>4} {f:>6}")
            if f > best_fit:
                best_fit = f; best_chrom = chrom[:]

        best_x = decode(best_chrom)
        print(f"  --> Best: {best_chrom}  x={best_x}  f={best_fit}")
        history.append((gen, best_fit, best_x))

        next_population = []
        if elitism:
            next_population.append(best_chrom[:])
        while len(next_population) < pop_size:
            p1 = roulette_select(population)
            p2 = roulette_select(population)
            point = random.randint(1, 3)
            o1, o2 = single_point_crossover(p1, p2, point)
            o1 = mutate(o1, p_m)
            o2 = mutate(o2, p_m)
            next_population.append(o1)
            if len(next_population) < pop_size:
                next_population.append(o2)
        population = next_population

    return history


# Silent version for repeated experiments

def run_ga_silent(pop_size, num_generations, p_m, elitism):
    """Same as run_ga but without printing, used for 30-trial experiments."""
    population = [[random.randint(0, 1) for _ in range(4)] for _ in range(pop_size)]
    history = []
    for gen in range(1, num_generations + 1):
        best_chrom = None; best_fit = -1
        for chrom in population:
            f = fitness(chrom)
            if f > best_fit:
                best_fit = f; best_chrom = chrom[:]
        history.append((gen, best_fit, decode(best_chrom)))
        next_population = []
        if elitism:
            next_population.append(best_chrom[:])
        while len(next_population) < pop_size:
            p1 = roulette_select(population)
            p2 = roulette_select(population)
            point = random.randint(1, 3)
            o1, o2 = single_point_crossover(p1, p2, point)
            o1 = mutate(o1, p_m); o2 = mutate(o2, p_m)
            next_population.append(o1)
            if len(next_population) < pop_size:
                next_population.append(o2)
        population = next_population
    return history


# Q4(c): Controlled Experiments

def experiments():
    """
    Q4(c) experiments:
    1. elitism=False vs elitism=True, 30 trials, pop=4, gen=20, p_m=0.1
    2. p_m in {0.01, 0.1, 0.3, 0.5}, 30 trials each
    """    
    TRIALS = 30
    POP_SIZE = 4
    NUM_GEN = 20

    print("\n" + "=" * 60)
    print("Q4(c): Experiment 1: Elitism False vs True (30 trials)")
    print("=" * 60)
    for elitism_flag, label in [(False, "elitism=False"), (True, "elitism=True")]:
        total_best = found_opt = 0
        gen_to_50 = []
        for _ in range(TRIALS):
            history = run_ga_silent(POP_SIZE, NUM_GEN, 0.1, elitism_flag)
            best_fit = max(f for (g, f, x) in history)
            total_best += best_fit
            if any(x == 7 for (g, f, x) in history):
                found_opt += 1
            for (g, f, x) in history:
                if f >= 50:
                    gen_to_50.append(g); break
        avg_best = total_best / TRIALS
        avg_gen = f"{sum(gen_to_50)/len(gen_to_50):.1f}" if gen_to_50 else "N/A"
        print(f"\n  [{label}]")
        print(f"    Avg best fitness:          {avg_best:.2f}")
        print(f"    Runs finding x=7:          {found_opt}/{TRIALS}")
        print(f"    Avg generations to f>=50:  {avg_gen}")

    print("\n" + "=" * 60)
    print("Q4(c): Experiment 2: Mutation Rate Sweep (30 trials each)")
    print("=" * 60)
    print(f"\n  {'p_m':<10} {'Avg Best Fitness'}")
    print("  " + "-" * 28)
    for p_m in [0.01, 0.1, 0.3, 0.5]:
        total_best = sum(max(f for (g, f, x) in run_ga_silent(POP_SIZE, NUM_GEN, p_m, False))
                         for _ in range(TRIALS))
        print(f"  {p_m:<10} {total_best/TRIALS:.2f}")


# Q4(d): Manual Walkthrough

def manual_walkthrough():
    """
    Q4(d): Full manual decode/select/crossover/mutate walkthrough.
    Manual: use exact population P1=[0,1,1,0], P2=[1,0,0,1],
            P3=[1,1,0,0], P4=[0,0,1,1]
            random numbers r1=0.12, r2=0.47, r3=0.68, r4=0.91
            crossover at position 2, mutation per-bit [0.08,0.43,0.91,0.05] pm=0.1
    """
    print("\n" + "=" * 60)
    print("Q4(d): Manual Generation Walkthrough")
    print("=" * 60)

    population = [[0,1,1,0], [1,0,0,1], [1,1,0,0], [0,0,1,1]]
    fitnesses = [fitness(c) for c in population]
    total_fit = sum(fitnesses)

    print(f"\nStep 1: Fitness table (total={total_fit}):")
    print(f"  {'Indiv':<8} {'Chromosome':<18} {'x':>4} {'f(x)':>6} {'Sel. Prob':>10}")
    print("  " + "-" * 50)
    for idx, chrom in enumerate(population):
        print(f"  P{idx+1:<6} {str(chrom):<18} {decode(chrom):>4} "
              f"{fitnesses[idx]:>6} {fitnesses[idx]/total_fit:>10.4f}")

    # Cumulative probabilities for roulette
    cumulative = []
    cumsum = 0
    for f in fitnesses:
        cumsum += f / total_fit
        cumulative.append(round(cumsum, 4))
    print(f"\n  Cumulative probabilities: {cumulative}")

    # Step 2: Roulette selection with given random numbers
    print("\nStep 2: Selection with r=[0.12, 0.47, 0.68, 0.91]:")
    selected = []
    for r in [0.12, 0.47, 0.68, 0.91]:
        for idx, cp in enumerate(cumulative):
            if r <= cp:
                selected.append(population[idx][:])
                print(f"  r={r} <= {cp} -> P{idx+1} = {population[idx]}")
                break
    print(f"\n  Parent Pair 1: {selected[0]} x {selected[1]}")
    print(f"  Parent Pair 2: {selected[2]} x {selected[3]}")

    # Step 3: Crossover at position 2
    print("\nStep 3: Single-point crossover at position 2:")
    o1, o2 = single_point_crossover(selected[0], selected[1], 2)
    o3, o4 = single_point_crossover(selected[2], selected[3], 2)
    print(f"  O1={o1}  x={decode(o1)}  f={fitness(o1)}")
    print(f"  O2={o2}  x={decode(o2)}  f={fitness(o2)}")
    print(f"  O3={o3}  x={decode(o3)}  f={fitness(o3)}")
    print(f"  O4={o4}  x={decode(o4)}  f={fitness(o4)}")

    # Step 4: Mutation on O1 with given per-bit randoms
    print("\nStep 4: Bit-flip mutation on O1, per-bit randoms=[0.08,0.43,0.91,0.05], pm=0.1:")
    per_bit = [0.08, 0.43, 0.91, 0.05]
    mutated_o1 = []
    for i, (bit, r) in enumerate(zip(o1, per_bit)):
        if r < 0.1:
            mutated_o1.append(1 - bit)
            print(f"  bit[{i}]: r={r} < 0.1 -> FLIP {bit} -> {1-bit}")
        else:
            mutated_o1.append(bit)
            print(f"  bit[{i}]: r={r} >= 0.1 -> keep {bit}")
    print(f"\n  O1 after mutation: {mutated_o1}  x={decode(mutated_o1)}  f={fitness(mutated_o1)}")


# Entry point
if __name__ == "__main__":
    test_core_functions()

    print("\n" + "=" * 60)
    print("Q4(b): Full GA Run: pop=4, gen=10, p_m=0.1, elitism=False")
    print("=" * 60)
    history = run_ga(pop_size=4, num_generations=10, p_m=0.1, elitism=False)

    print("\nGeneration Summary Table:")
    print(f"  {'Generation':<12} {'Best Fitness':<14} {'Best x'}")
    print("  " + "-" * 34)
    for (gen, best_fit, best_x) in history:
        print(f"  {gen:<12} {best_fit:<14} {best_x}")

    experiments()
    manual_walkthrough()
