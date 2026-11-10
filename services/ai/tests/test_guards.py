"""Garde-fous contre les transcriptions inventées (silence, boucles de répétition)."""

from app.asr.guards import foreign_script, is_near_silent, looks_hallucinated


def test_repetition_loop_is_rejected():
    text = (
        "toerampivarotana iray izay miendrika efajoro eny aminny sisiny dia misy karazana "
        "izay miendrika efajoro eny izay miendrika efajoro eny izay miendrika efajoro eny "
        "izay miendrika efajoro eny"
    )
    assert looks_hallucinated(text)


def test_normal_question_is_kept():
    assert not looks_hallucinated("rahoviana ny fizahana vohoka manaraka")
    assert not looks_hallucinated("")


def test_silence_detection():
    assert is_near_silent([0.0] * 16000)
    assert is_near_silent([])
    assert not is_near_silent([0.2, -0.2] * 8000)


def test_foreign_script():
    assert foreign_script("അത്.")
    assert not foreign_script("Mandeha ra aho, ary marary ny kiboko.")
    assert not foreign_script("Rendez-vous à l'hôpital")
