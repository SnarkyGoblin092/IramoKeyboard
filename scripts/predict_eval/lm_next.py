"""The current keyboard with next-word predictions from the new trigram language model (step 2 on its own)."""

import baseline
from lm import LanguageModel, Mixture


class Engine(baseline.Engine):
    name = "lm_next"

    def __init__(self, data_dir, enabled, active):
        super().__init__(data_dir, enabled, active)
        self.mixture = Mixture({lang: LanguageModel(lang, data_dir) for lang in self.ordered}, active)

    def next_words(self, before, limit=3):
        return self.mixture.next_words(before, limit)
