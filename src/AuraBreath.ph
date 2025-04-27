import sys
import webbrowser
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QPushButton, QLineEdit,
    QVBoxLayout, QHBoxLayout, QCheckBox, QMessageBox, QStackedLayout
)
from PyQt5.QtGui import QIcon, QColor, QFont, QPainter
from PyQt5.QtCore import Qt, QThread, pyqtSignal

class ColorSlideWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.start_color = QColor("#FF8C00")  # Default starting color
        self.end_color = QColor("#87CEEB")    # Next color
        self.progress = 0.0  # 0 to 1

    def set_colors(self, start_color, end_color):
        self.start_color = QColor(start_color)
        self.end_color = QColor(end_color)
        self.progress = 0.0
        self.update()

    def set_progress(self, value):
        self.progress = value
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        rect = self.rect()

        # Draw start color fully
        painter.fillRect(rect, self.start_color)

        # Draw the sliding color on top
        if self.progress > 0:
            slide_width = int(rect.width() * self.progress)
            sliding_rect = rect.adjusted(0, 0, -rect.width() + slide_width, 0)
            painter.fillRect(sliding_rect, self.end_color)

class BreathingThread(QThread):
    update_slide = pyqtSignal(float)
    update_colors = pyqtSignal(str, str)

    def __init__(self, inhale, hold, exhale):
        super().__init__()
        self.inhale = inhale
        self.hold = hold
        self.exhale = exhale
        self.running = True
        self.color_sequence = [
            ("#FF8C00", "#87CEEB", self.inhale),  # Exhale ➔ Inhale
            ("#87CEEB", "#4B0082", self.hold),    # Inhale ➔ Hold
            ("#4B0082", "#FF8C00", self.exhale)   # Hold ➔ Exhale
        ]

    def run(self):
        while self.running:
            for start_color, end_color, duration in self.color_sequence:
                if not self.running:
                    break
                self.update_colors.emit(start_color, end_color)
                steps = duration * 30  # 30 frames per second
                for i in range(steps):
                    if not self.running:
                        break
                    self.update_slide.emit(i / steps)
                    self.msleep(int(1000 / 30))  # smooth 30 FPS
                self.update_slide.emit(1.0)

    def stop(self):
        self.running = False

class AuraBreathApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("AuraBreath")
        self.setWindowIcon(QIcon("breath_icon.ico"))
        self.resize(500, 400)  # Resizable by default!
        self.setFont(QFont("Segoe UI", 10))
        self.thread = None

        self.init_ui()

    def init_ui(self):
        self.stack = QStackedLayout()
        self.setLayout(self.stack)

        # Main UI
        self.ui_widget = QWidget()
        ui_layout = QVBoxLayout()

        title = QLabel("AuraBreath")
        title.setFont(QFont("Segoe UI", 28, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)

        subtitle = QLabel("Version 1.1 by Rushikesh Malave")
        subtitle.setFont(QFont("Segoe UI", 10))
        subtitle.setAlignment(Qt.AlignCenter)

        self.inhale_input = self.make_input("6")
        self.hold_input = self.make_input("24")
        self.exhale_input = self.make_input("12")

        ui_layout.addWidget(title)
        ui_layout.addWidget(subtitle)
        ui_layout.addLayout(self.label_input("Inhale (Sky Blue):", self.inhale_input))
        ui_layout.addLayout(self.label_input("Hold (Indigo):", self.hold_input))
        ui_layout.addLayout(self.label_input("Exhale (Warm Orange):", self.exhale_input))

        self.top_cb = QCheckBox("Always on top")
        self.top_cb.stateChanged.connect(self.set_always_on_top)
        ui_layout.addWidget(self.top_cb)

        self.start_btn = QPushButton("Start")
        self.start_btn.clicked.connect(self.start_breathing)
        ui_layout.addWidget(self.start_btn)

        update_btn = QPushButton("Check for Updates")
        update_btn.clicked.connect(lambda: webbrowser.open("https://github.com/Rushikesh-Malave-175/AuraBreath"))
        ui_layout.addWidget(update_btn)

        self.ui_widget.setLayout(ui_layout)
        self.stack.addWidget(self.ui_widget)

        # Color Slide View
        self.color_widget = ColorSlideWidget()
        self.stack.addWidget(self.color_widget)

    def make_input(self, text):
        box = QLineEdit(text)
        box.setFont(QFont("Segoe UI", 10))
        return box

    def label_input(self, text, field):
        layout = QHBoxLayout()
        label = QLabel(text)
        label.setFont(QFont("Segoe UI", 10))
        layout.addWidget(label)
        layout.addWidget(field)
        return layout

    def set_always_on_top(self):
        self.setWindowFlag(Qt.WindowStaysOnTopHint, self.top_cb.isChecked())
        self.show()

    def start_breathing(self):
        try:
            inhale = int(self.inhale_input.text())
            hold = int(self.hold_input.text())
            exhale = int(self.exhale_input.text())
        except ValueError:
            QMessageBox.critical(self, "Input Error", "Enter valid seconds.")
            return

        # Switch to color animation view
        self.stack.setCurrentWidget(self.color_widget)

        if self.thread:
            self.thread.stop()
            self.thread.wait()

        self.thread = BreathingThread(inhale, hold, exhale)
        self.thread.update_slide.connect(self.color_widget.set_progress)
        self.thread.update_colors.connect(self.color_widget.set_colors)
        self.thread.start()

    def closeEvent(self, event):
        if self.thread:
            self.thread.stop()
            self.thread.wait()
        event.accept()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setFont(QFont("Segoe UI", 10))
    window = AuraBreathApp()
    window.show()
    sys.exit(app.exec_())
