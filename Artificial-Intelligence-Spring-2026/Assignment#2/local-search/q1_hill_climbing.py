"""
Q1: First-Choice HC and Stochastic HC
Section A, Q1
"""

import random


# Landscape: landscape[i] = f(i+1)
# State:  1   2   3   4   5   6   7   8   9  10  11  12
# f(s):   4   9   6  11   8  15  10   7  13   5  16  12
LANDSCAPE_Q1 = [4, 9, 6, 11, 8, 15, 10, 7, 13, 5, 16, 12]

# Q1(c) plateau landscape: states 5,6,7 all have f=15
LANDSCAPE_PLATEAU = [4, 9, 6, 11, 15, 15, 15, 7, 13, 5, 16, 12]

# Q1(a): First-Choice Hill Climbing
# Always check left neighbour before right; move immediately on first improvement

def first_choice_hc(landscape, start):
    """
    First-Choice HC: checks left neighbour first,
    moves immediately on first improvement.
    Returns (path, terminal_state) using 1-indexed states.
    """
    current = start     # 1-indexed state
    path = [current]
    while True:
        current_f = landscape[current - 1]      # f(current)
        moved = False
        # Check left neighbour (current-1) first, then right (current+1)
        left = current - 1
        right = current + 1
        if left >= 1 and landscape[left - 1] > current_f:
            current = left
            path.append(current)
            moved = True
        # Only check right if we didn't move left    
        if not moved and right <= len(landscape) and landscape[right - 1] > current_f:
            current = right
            path.append(current)
            moved = True
        # If we didn't move in either direction, we're at a local max (or plateau)    
        if not moved:
            break
    return (path, current)


# Q1(a): Stochastic Hill Climbing
# Collect all strictly uphill neighbours, then pick one using random.choice()

def stochastic_hc(landscape, start):
    """
    Stochastic HC: collects all strictly uphill neighbours,
    picks one at random using random.choice().
    Returns (path, terminal_state) using 1-indexed states.
    """
    current = start
    path = [current]
    while True:
        current_f = landscape[current - 1]
        uphill = []  # list of strictly better neighbours
        if current - 1 >= 1 and landscape[current - 2] > current_f:
            uphill.append(current - 1)
        if current + 1 <= len(landscape) and landscape[current] > current_f:
            uphill.append(current + 1)
        if not uphill:
            break   # no better neighbours, we're at a local max (or plateau)

        # Pick one of the uphill neighbours at random and move there
        current = random.choice(uphill)
        path.append(current)
    return (path, current)


# Q1(a): main() -> runs both from every starting state
# Print formatted results table: Start, Algorithm, Path, Terminal State, Steps

def main():
    landscape = LANDSCAPE_Q1
    num_states = len(landscape) # 12 states total, indexed 1 to 12

    print("=" * 70)
    print("Q1(a): Results Table")
    print("=" * 70)
    print(f"{'Start':<8} {'Algorithm':<14} {'Path':<30} {'Terminal':<10} {'Steps'}")
    print("-" * 70)

    for start in range(1, num_states + 1):
        # Run First-Choice HC and Stochastic HC from this starting state
        path_fc, term_fc = first_choice_hc(landscape, start)
        print(f"{start:<8} {'FirstChoice':<14} {str(path_fc):<30} {term_fc:<10} {len(path_fc)-1}")
        path_st, term_st = stochastic_hc(landscape, start)
        print(f"{start:<8} {'Stochastic':<14} {str(path_st):<30} {term_st:<10} {len(path_st)-1}")

    
    # Q1(b): Summary -> how many starting states reach global max (state 11)?
    # Presentation as summary table
    
    print("\nQ1(b): Starting states reaching global maximum (state 11):")
    print(f"{'Algorithm':<16} {'Reaches state 11'}")
    print("-" * 36)
    fc_count = sum(1 for s in range(1, num_states + 1)
                   if first_choice_hc(landscape, s)[1] == 11)
    st_count = sum(1 for s in range(1, num_states + 1)
                   if stochastic_hc(landscape, s)[1] == 11)
    print(f"{'FirstChoice':<16} {fc_count} / {num_states}")
    print(f"{'Stochastic':<16} {st_count} / {num_states}")


    # Q1(b): Divergence
    
    print("\nDivergence (states where algorithms reach different terminals):")
    for start in range(1, num_states + 1):
        _, t_fc = first_choice_hc(landscape, start)
        _, t_st = stochastic_hc(landscape, start)
        if t_fc != t_st:
            print(f"  Start={start}: FirstChoice -> state {t_fc} (f={landscape[t_fc-1]}), "
                  f"Stochastic -> state {t_st} (f={landscape[t_st-1]})")

    
    # Q1(b): 50 trials of Stochastic HC from s=4
    # -> random.seed() must NOT be fixed, allow true randomness
    
    print("\nQ1(b): Stochastic HC, 50 trials from s=4 (no fixed seed):")
    reach_global = sum(1 for _ in range(50) if stochastic_hc(landscape, 4)[1] == 11)
    pct = reach_global * 2.0
    print(f"  Reached state 11: {reach_global} / 50 ({pct:.1f}%)")
    print(f"  Did not reach 11: {50 - reach_global} / 50 ({100.0 - pct:.1f}%)")


# Q1(c): Plateau handling
# Change states {5,6,7} to f=15 in landscape, add plateau detection, add sideways-move extension (cap=10)

def first_choice_hc_plateau(landscape, start):
    """
    First-Choice HC with plateau detection.
    Prints a warning when stuck on a plateau (no strictly better
    neighbour but at least one equal neighbour exists).
    Returns (path, terminal_state, got_stuck_on_plateau).
    """
    current = start
    path = [current]
    stuck = False
    while True:
        current_f = landscape[current - 1]
        moved = False
        left = current - 1
        right = current + 1
        # Check left neighbour first, then right, for strictly better states
        if left >= 1 and landscape[left - 1] > current_f:
            current = left; path.append(current); moved = True
        if not moved and right <= len(landscape) and landscape[right - 1] > current_f:
            current = right; path.append(current); moved = True
        if not moved:
            # Check for plateau: no better neighbours, but at least one equal neighbour exists
            has_equal = (left >= 1 and landscape[left - 1] == current_f) or \
                        (right <= len(landscape) and landscape[right - 1] == current_f)
            if has_equal:
                print(f"  [PLATEAU WARNING] FirstChoice stuck at state {current} "
                      f"(f={current_f}) -- equal neighbours exist but no better one.")
                stuck = True
            break
    return (path, current, stuck)


def stochastic_hc_plateau(landscape, start):
    """
    Stochastic HC with plateau detection.
    Prints a warning when stuck on a plateau.
    Returns (path, terminal_state, got_stuck_on_plateau).
    """
    current = start
    path = [current]
    stuck = False
    while True:
        current_f = landscape[current - 1]
        uphill = []
        left = current - 1
        right = current + 1
        if left >= 1 and landscape[left - 1] > current_f:
            uphill.append(left)
        if right <= len(landscape) and landscape[right - 1] > current_f:
            uphill.append(right)
        if not uphill:
            # Check for plateau: no better neighbours, but at least one equal neighbour exists
            has_equal = (left >= 1 and landscape[left - 1] == current_f) or \
                        (right <= len(landscape) and landscape[right - 1] == current_f)
            if has_equal:
                print(f"  [PLATEAU WARNING] Stochastic stuck at state {current} "
                      f"(f={current_f}) -- equal neighbours exist but no better one.")
                stuck = True
            break
        current = random.choice(uphill)
        path.append(current)
    return (path, current, stuck)


def first_choice_hc_sideways(landscape, start, max_sideways=10):
    """
    First-Choice HC with sideways-move extension.
    Allows moves to equal-valued neighbours, capped at max_sideways per run.
    Returns (path, terminal_state).
    """
    current = start
    path = [current]
    sideways = 0
    while True:
        current_f = landscape[current - 1]
        moved = False
        left = current - 1
        right = current + 1
        # Check left neighbour first, then right, for strictly better states
        if left >= 1 and landscape[left - 1] > current_f:
            current = left; path.append(current); moved = True
        if not moved and right <= len(landscape) and landscape[right - 1] > current_f:
            current = right; path.append(current); moved = True

        # Try sideways move if no strict improvement and cap not hit    
        if not moved and sideways < max_sideways:
            if left >= 1 and landscape[left - 1] == current_f:
                current = left; path.append(current); sideways += 1; moved = True
            elif right <= len(landscape) and landscape[right - 1] == current_f:
                current = right; path.append(current); sideways += 1; moved = True
        if not moved:
            break
    return (path, current)


def stochastic_hc_sideways(landscape, start, max_sideways=10):
    """
    Stochastic HC with sideways-move extension.
    Allows moves to equal-valued neighbours, capped at max_sideways per run.
    Returns (path, terminal_state).
    """
    current = start
    path = [current]
    sideways = 0
    while True:
        current_f = landscape[current - 1]
        uphill, equal = [], []
        left = current - 1
        right = current + 1
        if left >= 1:
            if landscape[left - 1] > current_f: uphill.append(left)
            elif landscape[left - 1] == current_f: equal.append(left)
        if right <= len(landscape):
            if landscape[right - 1] > current_f: uphill.append(right)
            elif landscape[right - 1] == current_f: equal.append(right)
        if uphill:
            current = random.choice(uphill); path.append(current)
        elif equal and sideways < max_sideways:
            current = random.choice(equal); path.append(current); sideways += 1
        else:
            break
    return (path, current)


def main_plateau():
    """
    Q1(c): Re-run both algorithms on plateau landscape,
    then re-run with sideways-move extension and compare.
    """    
    landscape = LANDSCAPE_PLATEAU
    num_states = len(landscape)
    global_max = 11 # global max is still state 11 with f=16

    print("\n" + "=" * 70)
    print("Q1(c): Plateau Landscape (states 5, 6, 7 all f=15)")
    print("=" * 70)

    # First run without sideways moves, count how many get stuck on plateau vs reach global max
    print("\n[Without sideways moves]")
    fc_stuck = st_stuck = fc_global = st_global = 0
    for s in range(1, num_states + 1):
        _, t_fc, s_fc = first_choice_hc_plateau(landscape, s)
        _, t_st, s_st = stochastic_hc_plateau(landscape, s)
        if s_fc: fc_stuck += 1
        if s_st: st_stuck += 1
        if t_fc == global_max: fc_global += 1
        if t_st == global_max: st_global += 1

    # Print summary of plateau results
    print(f"\n  FirstChoice: stuck on plateau={fc_stuck}/12,  global max reached={fc_global}/12")
    print(f"  Stochastic:  stuck on plateau={st_stuck}/12,  global max reached={st_global}/12")

    # Now run with sideways moves allowed, and count how many reach global max (should improve)
    print("\n[With sideways moves, cap=10]")
    fc_sw = sum(1 for s in range(1, num_states + 1) 
                if first_choice_hc_sideways(landscape, s)[1] == global_max)
    st_sw = sum(1 for s in range(1, num_states + 1) 
                if stochastic_hc_sideways(landscape, s)[1] == global_max)
    print(f"  FirstChoice: global max reached={fc_sw}/12")
    print(f"  Stochastic:  global max reached={st_sw}/12")


# Entry point
if __name__ == "__main__":
    main()
    main_plateau()
