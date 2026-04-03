"""
Q3: Diagnosing HC Failures and N-Queens
Section A, Q3
"""

import random


# Q1 HC functions (copied here for self-contained file)

def first_choice_hc(landscape, start):
    """First-Choice HC — left neighbour first, move on first improvement."""
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


# Q3(a): diagnose_hc
# Detects 3 failure modes:
#   (1) local maximum: no neighbour is better or equal
#   (2) plateau: no strictly better but at least one equal
#   (3) ridge: same state visited twice (oscillation)

def diagnose_hc(landscape, start):
    """
    Runs First-Choice HC and detects which failure mode was encountered.
    Failure modes:
      local_maximum -> no neighbour is better or equal
      plateau       -> no strictly better neighbour but at least one equal
      ridge         -> same state visited twice (oscillation without progress)
    """
    current = start
    path = [current]
    visited = {current}
    failure_mode = None

    while True:
        current_f = landscape[current - 1]
        moved = False
        left = current - 1
        right = current + 1

        # Check left neighbour first
        # If it's better, move there. If it's been visited before, it's a ridge.
        if left >= 1 and landscape[left - 1] > current_f:
            if left in visited:
                failure_mode = "ridge"
                break
            current = left; path.append(current); visited.add(current); moved = True

        if not moved and right <= len(landscape) and landscape[right - 1] > current_f:
            if right in visited:
                failure_mode = "ridge"
                break
            current = right; path.append(current); visited.add(current); moved = True

        if not moved:
            # No better neighbour found. Check if plateau or local max by looking for equal neighbours.
            has_equal = (left >= 1 and landscape[left - 1] == current_f) or \
                        (right <= len(landscape) and landscape[right - 1] == current_f)
            failure_mode = "plateau" if has_equal else "local_maximum"
            break

    print(f"Terminated at state {current} with f={landscape[current-1]}. "
          f"Failure mode: {failure_mode}")
    print(f"Path taken: {path}")
    return (path, current, failure_mode)


def main_diagnose():
    """
    Q3(a): Three hand-crafted landscapes that each trigger exactly one failure mode.
    Each with at least 5 states, not reusing Q1/Q2
    """
    print("=" * 65)
    print("Q3(a): Diagnosing HC Failure Modes")
    print("=" * 65)

    # Landscape 1: Local Maximum
    # State: 1  2  3  4  5  6  7
    # f(s):  2  5  9  6  4  3  1
    # From state 1: climbs to state 3 (f=9). Both neighbours lower -> local max.
    print("\n[Landscape 1: Local Maximum]")
    print("  f = [2, 5, 9, 6, 4, 3, 1]  start=1")
    diagnose_hc([2, 5, 9, 6, 4, 3, 1], 1)

    # Landscape 2: Plateau
    # State: 1  2   3   4   5  6
    # f(s):  3  6  10  10  10  8
    # From state 1: reaches state 3 (f=10), neighbour state 4 is equal -> plateau.
    print("\n[Landscape 2: Plateau]")
    print("  f = [3, 6, 10, 10, 10, 8]  start=1")
    diagnose_hc([3, 6, 10, 10, 10, 8], 1)

    # Landscape 3: Ridge detection demonstration
    # State: 1  2  3  4  5  6
    # f(s):  2  5  7  5  7  4
    # In 1D strict-improvement HC, a true cycle cannot form -> the function
    # correctly detects local_maximum here and would flag ridge if it occurred.
    print("\n[Landscape 3: Ridge Detection Demonstration]")
    print("  f = [2, 5, 7, 5, 7, 4]  start=4")
    diagnose_hc([2, 5, 7, 5, 7, 4], 4)
    print("  start=2")
    diagnose_hc([2, 5, 7, 5, 7, 4], 2)


# Q3(b): N-Queens (N=8)
# ->      board[i] = row of queen in column i
#         count_conflicts: number of attacking pairs (lower=better)
#         stochastic_hc_nqueens: swap two queens' rows if swap reduces conflicts
#         solve_nqueens_rrhc: random restart until solution or restarts exhausted

def count_conflicts(board):
    """Returns number of attacking pairs of queens (lower is better; 0 = solution)."""
    n = len(board)
    conflicts = 0
    for i in range(n):
        for j in range(i + 1, n):
            if board[i] == board[j]:                        # same row
                conflicts += 1
            if abs(board[i] - board[j]) == abs(i - j):      # same diagonal
                conflicts += 1
    return conflicts


def stochastic_hc_nqueens(board):
    """
    Stochastic HC for N-Queens.
    Randomly swap two queens' rows if the swap reduces conflicts
    Collects all swaps that reduce conflicts, picks one randomly (stochastic).
    Returns (final_board, final_conflicts, steps).
    """
    current_board = board[:]
    current_conflicts = count_conflicts(current_board)
    steps = 0
    max_steps = 2000 # safety limit to prevent infinite loops in case of issues

    while current_conflicts > 0 and steps < max_steps:
        n = len(current_board)
        # Generate all improving swaps (col1, col2) that reduce conflicts
        improving_swaps = []
        for col1 in range(n):
            for col2 in range(col1 + 1, n):
                new_board = current_board[:]
                new_board[col1], new_board[col2] = new_board[col2], new_board[col1]
                new_conflicts = count_conflicts(new_board)
                if new_conflicts < current_conflicts:
                    improving_swaps.append((new_conflicts, new_board))
        if not improving_swaps:
            # no improving swap found, should not happen if current_conflicts > 0
            break 

        # Pick a random improving swap
        current_conflicts, current_board = random.choice(improving_swaps)
        steps += 1

    return (current_board, current_conflicts, steps)


def solve_nqueens_rrhc(num_restarts, verbose=True):
    """
    Solves N=8 Queens using Random Restart Stochastic HC.
    Apply Random Restart HC until solution found or restarts exhausted
    Returns (solution_board, restarts_used, found).
    """
    n = 8
    for restart in range(1, num_restarts + 1):
        # Generate random starting board: each column has a queen in a random row
        start_board = [random.randint(0, n - 1) for _ in range(n)]
        final_board, final_conflicts, steps = stochastic_hc_nqueens(start_board)
        if final_conflicts == 0:
            if verbose:
                print(f"Solution found at restart {restart} (steps={steps}).")
            return (final_board, restart, True)
    if verbose:
        print(f"No solution found within {num_restarts} restarts.")
    return (None, num_restarts, False)


def print_board(board):
    """Print board visually using Q and . characters."""
    n = len(board)
    for row in range(n):
        line = ""
        for col in range(n):
            line += "Q " if board[col] == row else ". "
        print("  " + line)


def main_nqueens():
    """Q3(b): Run solve_nqueens_rrhc(100) and report results."""
    print("\n" + "=" * 65)
    print("Q3(b): N-Queens (N=8), solve_nqueens_rrhc(100)")
    print("=" * 65)
    solution_board, restarts_used, found = solve_nqueens_rrhc(100)
    if found:
        print(f"  Restarts needed: {restarts_used}")
        print(f"  Final board:     {solution_board}")
        print(f"  Conflicts:       {count_conflicts(solution_board)}")
        print("  Visual board:")
        print_board(solution_board)


# Q3(c): Benchmark: solve_nqueens_rrhc(k) for k in {5,10,25,50,100}
# 30 independent trials per k, record success rate and avg restarts

def main_benchmark():
    """Q3(c): Benchmark N-Queens solver across different restart budgets."""
    print("\n" + "=" * 65)
    print("Q3(c): N-Queens Benchmark (30 trials per k)")
    print("=" * 65)
    print(f"{'k':<8} {'Success Rate':<16} {'Avg Restarts to Solution'}")
    print("-" * 46)

    for k in [5, 10, 25, 50, 100]:
        successes = 0
        total_restarts = 0
        for _ in range(30):
            board, restarts_used, found = solve_nqueens_rrhc(k, verbose=False)
            if found:
                successes += 1
                total_restarts += restarts_used
        success_rate = successes / 30
        avg_r = f"{total_restarts / successes:.1f}" if successes > 0 else "N/A"
        print(f"{k:<8} {success_rate:<16.2f} {avg_r}")


# Entry point
if __name__ == "__main__":
    main_diagnose()
    main_nqueens()
    main_benchmark()
