"""
Q5: Genetic Algorithm for Course Scheduling Problem
Section B, Q5
Problem: Schedule 6 courses {C1..C6} into 4 time slots {T1..T4} and 3 rooms {R1..R3}. No two courses may share same room AND same slot.
Chromosome: list of 6 tuples [(room_idx, slot_idx), ...]
"""

import random


# Q5(a): Representation and Fitness

def random_chromosome():
    """
    Generates a random valid-format chromosome.
    -> list of 6 tuples [(room_idx, slot_idx), ...], room_idx in {0,1,2}, slot_idx in {0,1,2,3}
    """
    return [(random.randint(0, 2), random.randint(0, 3)) for _ in range(6)]


def count_conflicts(chromosome):
    """
    Counts pairs of courses assigned to same room AND same time slot.
    each such pair = 1 conflict.
    """
    conflicts = 0
    n = len(chromosome)
    for i in range(n):
        for j in range(i + 1, n):
            if chromosome[i][0] == chromosome[j][0] and chromosome[i][1] == chromosome[j][1]:
                conflicts += 1
    return conflicts


def fitness_schedule(chromosome):
    """Fitness = 100 - (10 * conflicts). Conflict-free schedule scores 100."""
    return 100 - (10 * count_conflicts(chromosome))


def test_random_chromosomes():
    """Q5(a): Generate and print 5 random chromosomes with conflicts and fitness."""
    print("=" * 65)
    print("Q5(a): Random Chromosomes, Conflicts, and Fitness")
    print("=" * 65)
    print(f"\n  {'#':<4} {'Chromosome':<40} {'Conflicts':>10} {'Fitness':>8}")
    print("  " + "-" * 65)
    for i in range(5):
        chrom = random_chromosome()
        c = count_conflicts(chrom)
        f = fitness_schedule(chrom)
        print(f"  {i+1:<4} {str(chrom):<40} {c:>10} {f:>8}")


# Q5(b): Constraint-Aware Crossover and Mutation

def crossover(p1, p2, point):
    """
    Standard single-point crossover.
    Manual: may produce conflicting offspring — repair handles it afterward.
    """
    return p1[:point] + p2[point:], p2[:point] + p1[point:]


def repair(chromosome):
    """
    Detects conflicting courses and reassigns them to a conflict-free (room, slot).
    If no conflict-free slot exists, assigns randomly.
    """
    repaired = chromosome[:]
    n = len(repaired)
    for i in range(n):
        for j in range(i + 1, n):
            if repaired[i][0] == repaired[j][0] and repaired[i][1] == repaired[j][1]:
                # Conflict detected for course j (and i). Try to find a new slot for j.
                all_slots = [(r, s) for r in range(3) for s in range(4)]
                random.shuffle(all_slots)
                fixed = False
                for (room, slot) in all_slots:
                    if all(not (repaired[k][0] == room and repaired[k][1] == slot)
                           for k in range(n) if k != j):
                        repaired[j] = (room, slot); fixed = True; break
                if not fixed:
                    repaired[j] = (random.randint(0, 2), random.randint(0, 3))
    return repaired


def mutate_schedule(chromosome, p_m):
    """
    With probability p_m per gene, reassign course to random (room, slot).
    mutate(chromosome, p_m)
    """
    return [(random.randint(0, 2), random.randint(0, 3))
            if random.random() < p_m else gene
            for gene in chromosome]


def demo_crossover_repair():
    """Q5(b): Show crossover creating a conflict, then repair resolving it."""
    print("\n" + "=" * 65)
    print("Q5(b): Crossover Creates Conflict, Repair Resolves It")
    print("=" * 65)

    p1 = [(0, 0), (1, 1), (2, 2), (0, 3), (1, 2), (2, 1)]
    p2 = [(0, 0), (2, 1), (1, 2), (0, 2), (1, 3), (2, 0)]
    print(f"\n  Parent 1: {p1}  conflicts={count_conflicts(p1)}")
    print(f"  Parent 2: {p2}  conflicts={count_conflicts(p2)}")

    o1, o2 = crossover(p1, p2, 3)
    print(f"\n  Crossover at point 3:")
    print(f"    Offspring 1: {o1}  conflicts={count_conflicts(o1)}")
    repaired = repair(o1)
    print(f"    Repaired O1: {repaired}  conflicts={count_conflicts(repaired)}")

    # Manual conflict demo: create a chromosome with known conflicts and show repair.
    print("\n  Manual conflict demo:")
    conflict_chrom = [(0, 0), (0, 0), (1, 1), (1, 1), (2, 2), (2, 2)]
    repaired2 = repair(conflict_chrom)
    print(f"    Before: {conflict_chrom}  conflicts={count_conflicts(conflict_chrom)}")
    print(f"    After:  {repaired2}  conflicts={count_conflicts(repaired2)}")


# Q5(c): Full Scheduling GA

def tournament_select(population, tournament_size=2):
    """
    Tournament selection: pick tournament_size individuals randomly,
    return the fitter one. tournament size = 2.
    """
    competitors = random.sample(population, tournament_size)
    return max(competitors, key=fitness_schedule)


def run_scheduling_ga(pop_size, generations, p_m):
    """
    Full scheduling GA with tournament selection (size=2) and repair after crossover.
    Prints 'Solution found at generation X' if a conflict-free schedule is found.
    Returns (best_chromosome, best_fitness, fitness_history).
    """
    population = [random_chromosome() for _ in range(pop_size)]
    fitness_history = []
    best_chrom_overall = None
    best_fit_overall = -1
    solution_gen = None

    for gen in range(1, generations + 1):
        best_chrom_gen = max(population, key=fitness_schedule)
        best_fit_gen = fitness_schedule(best_chrom_gen)
        fitness_history.append(best_fit_gen)

        if best_fit_gen > best_fit_overall:
            best_fit_overall = best_fit_gen
            best_chrom_overall = best_chrom_gen[:]

        if best_fit_gen == 100 and solution_gen is None:
            solution_gen = gen
            print(f"  Solution found at generation {gen}: {best_chrom_gen}")

        next_population = []
        while len(next_population) < pop_size:
            parent1 = tournament_select(population, tournament_size=2)
            parent2 = tournament_select(population, tournament_size=2)
            point = random.randint(1, 5)
            o1, o2 = crossover(parent1, parent2, point)
            o1 = repair(o1)           # repair after every crossover (manual requirement)
            o2 = repair(o2)
            o1 = mutate_schedule(o1, p_m)
            o2 = mutate_schedule(o2, p_m)
            next_population.append(o1)
            if len(next_population) < pop_size:
                next_population.append(o2)
        population = next_population

    return (best_chrom_overall, best_fit_overall, fitness_history)


def print_schedule(chromosome):
    """Print schedule in readable room/slot format."""
    rooms = ["R1", "R2", "R3"]
    slots = ["T1", "T2", "T3", "T4"]
    print(f"\n  {'Course':<10} {'Room':<8} {'Slot'}")
    print("  " + "-" * 26)
    for i, (r, s) in enumerate(chromosome):
        print(f"  C{i+1:<9} {rooms[r]:<8} {slots[s]}")


# Entry point
if __name__ == "__main__":
    test_random_chromosomes()
    demo_crossover_repair()

    print("\n" + "=" * 65)
    print("Q5(c): Scheduling GA: pop=20, gen=50, p_m=0.1")
    print("=" * 65)
    best_chrom, best_fit, history = run_scheduling_ga(pop_size=20, generations=50, p_m=0.1)

    print(f"\nBest schedule found:")
    print_schedule(best_chrom)
    print(f"\n  Conflicts: {count_conflicts(best_chrom)}")
    print(f"  Fitness:   {best_fit}")

    print(f"\nBest fitness per generation:")
    for i, f in enumerate(history):
        print(f"  Gen {i+1:>3}: {f}")
