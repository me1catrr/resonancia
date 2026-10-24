from manim import *
import numpy as np


class VibracionPrueba(Scene):
    def construct(self):
        titulo = Text("Vibraciones estructurales", font_size=40)
        titulo.to_edge(UP)

        eje = Line(LEFT * 3, RIGHT * 3, color=GRAY)
        masa = Dot(color=BLUE, radius=0.15)

        t = ValueTracker(0)

        masa.add_updater(
            lambda m: m.move_to(
                np.array([
                    2 * np.sin(2 * t.get_value()),
                    0.5,
                    0
                ])
            )
        )

        self.add(titulo, eje, masa)
        self.play(
            t.animate.set_value(10),
            run_time=5,
            rate_func=linear
        )
        self.wait(0.5)
