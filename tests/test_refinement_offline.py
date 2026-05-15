from src.agents.refinement_agent import _accept

BASE = {ax: {"score": 3} for ax in
        ["objective_clarity","technical_progress_evidence",
         "data_and_metrics_rigor","transitions_concreteness",
         "citation_grounding","writing_clarity"]}
def mk(overall, **overrides):
    r = {**BASE, **overrides}
    r["overall"] = {"score": overall}
    return r

def test_accept_when_overall_increases():
    assert _accept(mk(3), mk(4)) is True

def test_revert_when_overall_decreases():
    assert _accept(mk(4), mk(3)) is False

def test_revert_on_tie_with_subaxis_decrease():
    old = mk(3)
    new = mk(3, writing_clarity={"score": 2})
    assert _accept(old, new) is False

def test_accept_on_tie_with_no_decreases():
    old = mk(3)
    new = mk(3, writing_clarity={"score": 4})
    assert _accept(old, new) is True
