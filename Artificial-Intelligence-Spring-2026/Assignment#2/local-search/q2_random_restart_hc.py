"""
Q2: Random Restart Hill Climbing
Section A, Q2
"""

import random


# Landscape: landscape[i] = f(i+1)
# State:  1   2   3   4   5   6   7   8   9  10  11  12  13  14
# f(s):   5   8   6  12   9   7  17  14  10   6  19  15  11   8
LANDSCAPE_Q2 = [5, 8, 6, 12, 9, 7, 17, 14, 10, 6, 19, 15, 11, 8]

# Q1 HC functions (copied here to keep file self-contained)

def first_choice_hc(landscape, start):
    """First-Choice HC: check left neighbour first, move on first improvement."""
    current = start
    path = [current]
    while True:
        current_f = landscape[current - 1]
        moved = False
        left = current - 1
        right = current + 1
        if left >= 1 and landscape[left - 1] > current_f:
            current = left; path.append(current); moved = True
        if not moved and right <= len(landscape) and landscape[right - 1] > current_f:
            current = right; path.append(current); moved = True
        if not moved:
            break
    return (path, current)


def stochastic_hc(landscape, start):
    """Stochastic HC: collect all uphill neighbours, pick one at random."""
    current = start
    path = [current]
    while True:
        current_f = landscape[current - 1]
        uphill = []
        if current - 1 >= 1 and landscape[current - 2] > current_f:
            uphill.append(current - 1)
        if current + 1 <= len(landscape) and landscape[current] > current_f:
            uphill.append(current + 1)
        if not uphill:
            break
        current = random.choice(uphill)
        path.append(current)
    return (path, current)


# Q2(a): Helper: find_local_maxima
# Returns all positions whose f-value exceeds both neighbours

def find_local_maxima(landscape):
    """
    Returns all 1-indexed states that are local maxima
    i.e., f(s) > f(s-1) and f(s) > f(s+1) where neighbours exist.
    Boundary states only need to beat the one neighbour they have.
    """
    maxima = []
    n = len(landscape)
    for i in range(n):
        f = landscape[i]                                 # f(s) for state s=i+1
        left_ok = (i == 0) or f > landscape[i - 1]       # left neighbour is i-1, state s=i
        right_ok = (i == n - 1) or f > landscape[i + 1]  # right neighbour is i+1, state s=i+2
        if left_ok and right_ok:
            maxima.append(i + 1)
    return maxima


# Q2(a): Random Restart HC
# Returns (best_state, best_value, all_results)
# all_results is list of (start, terminal, path)

def random_restart_hc(landscape, num_restarts, variant='first_choice'):
    """
    Random Restart HC.
    Returns (best_state, best_value, all_results).
    all_results is a list of (start, terminal, path) tuples.
    """
    all_results = []
    best_state = None
    best_value = -1 # Assuming all f-values are non-negative; adjust if negatives possible.
    for _ in range(num_restarts):
        # Select start state via random.randint(0, len(landscape)-1)
        start = random.randint(0, len(landscape) - 1) + 1
        if variant == 'first_choice':
            path, terminal = first_choice_hc(landscape, start)
        else:
            path, terminal = stochastic_hc(landscape, start)
        terminal_value = landscape[terminal - 1]
        all_results.append((start, terminal, path))
        if terminal_value > best_value:
            best_value = terminal_value
            best_state = terminal
    return (best_state, best_value, all_results)


# Q2(a): main() -> RRHC with 20 restarts, both variants, restart-by-restart table

def main():
    landscape = LANDSCAPE_Q2
    global_max_state = 11 # state with f=19, the global maximum

    # Local maxima
    maxima = find_local_maxima(landscape)
    print("Q2(a): Local maxima in Q2 landscape:")
    for s in maxima:
        print(f"  State {s}: f={landscape[s-1]}")

    # RRHC 20 restarts: First-Choice
    print("\nQ2(a): RRHC, 20 restarts, First-Choice HC:")
    print(f"{'Restart':<10} {'Start':<8} {'Terminal':<10} {'f(terminal)':<14} {'Global Max?'}")
    print("-" * 50)
    best_s, best_v, results = random_restart_hc(landscape, 20, 'first_choice')
    for idx, (start, terminal, path) in enumerate(results):
        found = "Yes" if terminal == global_max_state else "No"
        print(f"{idx+1:<10} {start:<8} {terminal:<10} {landscape[terminal-1]:<14} {found}")
    print(f"Best: state {best_s}, f={best_v}")

    # RRHC 20 restarts: Stochastic
    print("\nQ2(a): RRHC, 20 restarts, Stochastic HC:")
    print(f"{'Restart':<10} {'Start':<8} {'Terminal':<10} {'f(terminal)':<14} {'Global Max?'}")
    print("-" * 50)
    best_s, best_v, results = random_restart_hc(landscape, 20, 'stochastic')
    for idx, (start, terminal, path) in enumerate(results):
        found = "Yes" if terminal == global_max_state else "No"
        print(f"{idx+1:<10} {start:<8} {terminal:<10} {landscape[terminal-1]:<14} {found}")
    print(f"Best: state {best_s}, f={best_v}")

    
    # Q2(b): Experiments with n in {1, 3, 5, 10, 20} restarts
    # for each n, repeat 100 independent trials, compute empirical probability of finding global maximum
    
    print("\nQ2(b): Empirical probability of finding global max:")
    restart_counts = [1, 3, 5, 10, 20]
    trials = 100
    for n in restart_counts:
        successes = sum(1 for _ in range(trials)
                        if random_restart_hc(landscape, n, 'first_choice')[0] == global_max_state)
        print(f"  n={n:<4}: empirical P = {successes/trials:.2f}  ({successes}/{trials})")

    # Theoretical probabilities
    # p = fraction of starting states that reach state 11 under First-Choice HC
    reach_count = sum(1 for s in range(1, len(landscape) + 1)
                      if first_choice_hc(landscape, s)[1] == global_max_state)
    p = reach_count / len(landscape)
    print(f"\nQ2(b): Theoretical: p = {reach_count}/{len(landscape)} = {p:.4f}")
    print(f"{'n':<6} {'Empirical P':<14} {'Theoretical P'}")
    print("-" * 38)
    for n in restart_counts:
        successes = sum(1 for _ in range(trials)
                        if random_restart_hc(landscape, n, 'first_choice')[0] == global_max_state)
        theoretical = 1 - (1 - p) ** n
        print(f"{n:<6} {successes/trials:<14.2f} {theoretical:.4f}")


# Q2(c): Plateau investigation
# Modify states {7,8} to both have f=17, compare global max discovery rate before/after, add plateau counter inside RRHC

def random_restart_hc_plateau(landscape, num_restarts, variant='first_choice'):
    """
    RRHC with plateau counter.
    Counts how many restarts terminate on the plateau (state 7 or 8).
    Returns (best_state, best_value, all_results, plateau_count).
    """
    all_results = []
    best_state = None
    best_value = -1
    plateau_count = 0 # Count how many times we end on the plateau (state 7 or 8).
    for _ in range(num_restarts):
        start = random.randint(0, len(landscape) - 1) + 1
        if variant == 'first_choice':
            path, terminal = first_choice_hc(landscape, start)
        else:
            path, terminal = stochastic_hc(landscape, start)
        terminal_value = landscape[terminal - 1]
        all_results.append((start, terminal, path))
        if terminal in (7, 8): # If we end on state 7 or 8, it's a plateau termination.
            plateau_count += 1
        if terminal_value > best_value:
            best_value = terminal_value
            best_state = terminal
    return (best_state, best_value, all_results, plateau_count)


def main_plateau():
    """Q2(c): Plateau landscape investigation."""
    # Original Q2 landscape
    landscape_original = [5, 8, 6, 12, 9, 7, 17, 14, 10, 6, 19, 15, 11, 8]
    # Modified: states 7 and 8 both get f=17 (plateau)
    landscape_plateau = [5, 8, 6, 12, 9, 7, 17, 17, 10, 6, 19, 15, 11, 8]
    global_max_state = 11
    trials = 10

    print("\nQ2(c): Plateau investigation (states 7 and 8 both f=17):")
    print(f"{'Landscape':<30} {'Discovery Rate':<18} {'Avg plateau terminations'}")
    print("-" * 70)

    for label, landscape in [("Original", landscape_original),("Plateau (states 7,8=17)", landscape_plateau)]:
        found_count = 0
        total_plateau = 0
        for _ in range(trials):
            best_s, _, _, p_count = random_restart_hc_plateau(landscape, 20, 'first_choice')
            if best_s == global_max_state:
                found_count += 1
            total_plateau += p_count
        rate = found_count / trials
        avg_p = total_plateau / trials
        print(f"  {label:<28} {rate:<18.2f} {avg_p:.1f}")


# Entry point
if __name__ == "__main__":
    main()
    main_plateau()
