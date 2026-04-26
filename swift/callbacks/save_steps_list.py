# Copyright (c) ModelScope Contributors. All rights reserved.
from .base import TrainerCallback


class SaveStepsListCallback(TrainerCallback):
    """Save checkpoints at specific steps defined as a list."""

    def on_step_end(self, args, state, control, **kwargs):
        if state.global_step in set(self.args.save_steps_list):
            control.should_save = True
        return control
