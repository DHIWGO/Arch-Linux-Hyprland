#!/usr/bin/env python3
"""
HyprArch Control Center — Centro de Control v2.0
Interfaz gráfica para gestionar Hyprland sin tocar archivos de configuración.

Dependencias: python-pyqt6, python-requests, python-psutil
Instalación:  pacman -S python-pyqt6 python-requests python-psutil
"""

import sys
import os
import json
import subprocess
import threading
from pathlib import Path
from typing import Optional

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QSlider, QGroupBox, QTabWidget, QColorDialog,
    QScrollArea, QFrame, QComboBox, QLineEdit, QTableWidget,
    QTableWidgetItem, QHeaderView, QSystemTrayIcon, QMenu, QMessageBox,
    QSizePolicy, QSpacerItem, QDialog, QDialogButtonBox,
)
from PyQt6.QtCore import (
    Qt, QThread, pyqtSignal, QTimer, QSize, QPropertyAnimation,
    QEasingCurve, QRect,
)
from PyQt6.QtGui import (
    QColor, QPalette, QFont, QIcon, QPixmap, QPainter, QBrush,
    QLinearGradient, QAction,
)

# ─── Paths ────────────────────────────────────────────────────────────────────
CONFIG_DIR   = Path.home() / ".config" / "hypr"
THEME_JSON   = CONFIG_DIR / "user_theme.json"
THEME_LUA    = CONFIG_DIR / "theme.lua"
PROFILE_LUA  = CONFIG_DIR / "active_profile.lua"
BINDS_LUA    = CONFIG_DIR / "user_binds.lua"
PRESETS_DIR  = CONFIG_DIR / "presets"

# ─── Design Tokens ────────────────────────────────────────────────────────────
STYLE = """
QMainWindow, QWidget#central {
    background: #0d0e1a;
}
QTabWidget::pane {
    border: 1px solid #2a2b3d;
    background: #0d0e1a;
    border-radius: 8px;
}
QTabBar::tab {
    background: #13142a;
    color: #7a7aaa;
    padding: 10px 22px;
    border: none;
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.5px;
}
QTabBar::tab:selected {
    background: #1c1d36;
    color: #5999ff;
    border-bottom: 2px solid #5999ff;
}
QTabBar::tab:hover:!selected {
    background: #17182e;
    color: #aaaacc;
}
QGroupBox {
    background: #13142a;
    border: 1px solid #2a2b3d;
    border-radius: 10px;
    margin-top: 14px;
    padding: 12px;
    font-size: 11px;
    font-weight: 700;
    color: #5999ff;
    letter-spacing: 1.5px;
    text-transform: uppercase;
}
QGroupBox::title {
    subcontrol-origin: margin;
    left: 12px;
    padding: 0 6px;
}
QLabel {
    color: #c8c8e0;
    font-size: 13px;
}
QSlider::groove:horizontal {
    height: 4px;
    background: #2a2b3d;
    border-radius: 2px;
}
QSlider::handle:horizontal {
    background: #5999ff;
    width: 16px;
    height: 16px;
    margin: -6px 0;
    border-radius: 8px;
}
QSlider::sub-page:horizontal {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #3366cc, stop:1 #5999ff);
    border-radius: 2px;
}
QPushButton {
    background: #1c1d36;
    color: #c8c8e0;
    border: 1px solid #3a3b5a;
    border-radius: 8px;
    padding: 8px 20px;
    font-size: 13px;
    font-weight: 500;
}
QPushButton:hover {
    background: #25264a;
    border-color: #5999ff;
    color: #ffffff;
}
QPushButton:pressed {
    background: #5999ff;
    color: #ffffff;
}
QPushButton#btnAccent {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #3366cc, stop:1 #5999ff);
    color: white;
    border: none;
    font-weight: 700;
}
QPushButton#btnAccent:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #4477dd, stop:1 #66aaff);
}
QPushButton#btnLite   { background: #1e2a1a; border-color: #4aaa4a; color: #4aaa4a; }
QPushButton#btnNormal { background: #1a2240; border-color: #5999ff; color: #5999ff; }
QPushButton#btnFull   { background: #2a1a3a; border-color: #aa55ff; color: #aa55ff; }
QPushButton#btnLite:hover   { background: #4aaa4a; color: white; }
QPushButton#btnNormal:hover { background: #5999ff; color: white; }
QPushButton#btnFull:hover   { background: #aa55ff; color: white; }
QPushButton#btnActive {
    border-width: 2px;
    font-weight: 700;
}
QComboBox {
    background: #1c1d36;
    color: #c8c8e0;
    border: 1px solid #3a3b5a;
    border-radius: 6px;
    padding: 6px 12px;
    font-size: 13px;
}
QComboBox::drop-down {
    border: none;
    width: 24px;
}
QComboBox QAbstractItemView {
    background: #1c1d36;
    color: #c8c8e0;
    selection-background-color: #3366cc;
    border: 1px solid #3a3b5a;
}
QLineEdit {
    background: #1c1d36;
    color: #c8c8e0;
    border: 1px solid #3a3b5a;
    border-radius: 6px;
    padding: 6px 12px;
    font-size: 13px;
}
QLineEdit:focus {
    border-color: #5999ff;
}
QTableWidget {
    background: #13142a;
    color: #c8c8e0;
    border: 1px solid #2a2b3d;
    border-radius: 6px;
    gridline-color: #1e1f38;
    font-size: 13px;
}
QTableWidget::item:selected {
    background: #3366cc;
    color: white;
}
QHeaderView::section {
    background: #1c1d36;
    color: #7a7aaa;
    border: none;
    padding: 8px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
}
QScrollBar:vertical {
    background: #13142a;
    width: 6px;
    border-radius: 3px;
}
QScrollBar::handle:vertical {
    background: #3a3b5a;
    border-radius: 3px;
    min-height: 30px;
}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
"""

# ─── Hyprctl Dispatcher ───────────────────────────────────────────────────────
class Hyprctl:
    """Wrapper para hyprctl con aplicación instantánea de cambios."""

    @staticmethod
    def dispatch(cmd: str, args: str = ""):
        """Envía un dispatch a Hyprland."""
        try:
            subprocess.Popen(
                ["hyprctl", "dispatch", cmd, args],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except FileNotFoundError:
            pass  # Hyprland no disponible (modo dev/test)

    @staticmethod
    def keyword(key: str, value: str):
        """Cambia una keyword en tiempo real."""
        try:
            result = subprocess.run(
                ["hyprctl", "keyword", key, value],
                capture_output=True, text=True, timeout=2
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    @staticmethod
    def reload():
        """Recarga la configuración completa."""
        try:
            subprocess.run(["hyprctl", "reload"], timeout=3,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    @staticmethod
    def batch(commands: list):
        """Aplica múltiples keywords en lote."""
        payload = "; ".join(f"keyword {k} {v}" for k, v in commands)
        try:
            subprocess.run(
                ["hyprctl", "--batch", payload],
                timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass


# ─── Theme Manager ────────────────────────────────────────────────────────────
class ThemeManager:
    """Gestión del archivo JSON de tema y generación del .lua."""

    def __init__(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        self.theme = self._load()

    def _load(self) -> dict:
        if THEME_JSON.exists():
            try:
                with open(THEME_JSON) as f:
                    return json.load(f)
            except json.JSONDecodeError:
                pass
        return self._defaults()

    def _defaults(self) -> dict:
        return {
            "profile": "normal",
            "colors": {
                "col_active": "#5999FF",
                "col_inactive": "#32324A",
                "col_shadow": "#00000080",
            },
            "borders": {"border_size": 2, "rounding": 10},
            "spacing": {"gaps_in": 5, "gaps_out": 10},
            "opacity": {"active_opacity": 1.0, "inactive_opacity": 0.9},
        }

    def save(self):
        with open(THEME_JSON, "w") as f:
            json.dump(self.theme, f, indent=2)
        self._generate_lua()

    def _generate_lua(self):
        c = self.theme.get("colors", {})
        b = self.theme.get("borders", {})
        s = self.theme.get("spacing", {})
        o = self.theme.get("opacity", {})

        def to_rgb(hex_color: str) -> str:
            h = hex_color.lstrip("#")
            if len(h) == 6:
                r, g, b_ = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
                return f"rgb({r},{g},{b_})"
            elif len(h) == 8:
                r, g, b_, a = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), int(h[6:8],16)
                return f"rgba({r},{g},{b_},{a/255:.2f})"
            return f"rgb(89,153,255)"

        lua = f"""-- theme.lua — Generado por HyprArch Control Center
-- NO editar manualmente.

return {{
  col_active        = "{to_rgb(c.get('col_active', '#5999FF'))}",
  col_inactive      = "{to_rgb(c.get('col_inactive', '#32324A'))}",
  col_shadow        = "{to_rgb(c.get('col_shadow', '#00000080'))}",
  border_size       = {b.get('border_size', 2)},
  gaps_in           = {s.get('gaps_in', 5)},
  gaps_out          = {s.get('gaps_out', 10)},
  rounding          = {b.get('rounding', 10)},
  active_opacity    = {o.get('active_opacity', 1.0):.2f},
  inactive_opacity  = {o.get('inactive_opacity', 0.9):.2f},
}}
"""
        with open(THEME_LUA, "w") as f:
            f.write(lua)

    def apply_live(self, key: str, value):
        """Aplica un cambio inmediatamente via hyprctl."""
        mapping = {
            "border_size":       ("general:border_size", str(value)),
            "gaps_in":           ("general:gaps_in", str(value)),
            "gaps_out":          ("general:gaps_out", str(value)),
            "rounding":          ("decoration:rounding", str(value)),
            "active_opacity":    ("decoration:active_opacity", f"{value:.2f}"),
            "inactive_opacity":  ("decoration:inactive_opacity", f"{value:.2f}"),
            "col_active":        ("general:col.active_border", self._to_hypr_color(value)),
            "col_inactive":      ("general:col.inactive_border", self._to_hypr_color(value)),
        }
        if key in mapping:
            Hyprctl.keyword(*mapping[key])

    @staticmethod
    def _to_hypr_color(hex_color: str) -> str:
        h = hex_color.lstrip("#")
        if len(h) == 6:
            return f"rgb({h})"
        return f"rgba({h})"

    def set_profile(self, name: str):
        self.theme["profile"] = name
        with open(PROFILE_LUA, "w") as f:
            f.write(f'return {{ name = "{name}" }}\n')
        self.save()
        Hyprctl.reload()


# ─── Color Button Widget ──────────────────────────────────────────────────────
class ColorButton(QPushButton):
    colorChanged = pyqtSignal(str)

    def __init__(self, color: str = "#5999FF", parent=None):
        super().__init__(parent)
        self._color = color
        self.setFixedSize(44, 44)
        self._update_style()
        self.clicked.connect(self._pick)

    def _update_style(self):
        self.setStyleSheet(f"""
            QPushButton {{
                background: {self._color};
                border: 2px solid rgba(255,255,255,0.2);
                border-radius: 8px;
            }}
            QPushButton:hover {{
                border-color: rgba(255,255,255,0.6);
            }}
        """)

    def _pick(self):
        initial = QColor(self._color)
        color = QColorDialog.getColor(initial, self, "Seleccionar Color",
                                      QColorDialog.ColorDialogOption.ShowAlphaChannel)
        if color.isValid():
            self._color = color.name(QColor.NameFormat.HexRgb)
            self._update_style()
            self.colorChanged.emit(self._color)

    @property
    def color(self) -> str:
        return self._color

    def set_color(self, c: str):
        self._color = c
        self._update_style()


# ─── Slider Row Widget ────────────────────────────────────────────────────────
class SliderRow(QWidget):
    valueChanged = pyqtSignal(int)

    def __init__(self, label: str, min_: int, max_: int, value: int,
                 suffix: str = "", parent=None):
        super().__init__(parent)
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 4, 0, 4)

        lbl = QLabel(label)
        lbl.setFixedWidth(160)
        layout.addWidget(lbl)

        self.slider = QSlider(Qt.Orientation.Horizontal)
        self.slider.setRange(min_, max_)
        self.slider.setValue(value)
        layout.addWidget(self.slider, 1)

        self.val_label = QLabel(f"{value}{suffix}")
        self.val_label.setFixedWidth(50)
        self.val_label.setAlignment(Qt.AlignmentFlag.AlignRight)
        self.val_label.setStyleSheet("color: #5999ff; font-weight: 700;")
        layout.addWidget(self.val_label)

        self.suffix = suffix
        self.slider.valueChanged.connect(self._on_change)

    def _on_change(self, val: int):
        self.val_label.setText(f"{val}{self.suffix}")
        self.valueChanged.emit(val)

    @property
    def value(self) -> int:
        return self.slider.value()

    def set_value(self, v: int):
        self.slider.setValue(v)


# ─── Visual Tab ───────────────────────────────────────────────────────────────
class VisualTab(QWidget):
    def __init__(self, tm: ThemeManager, parent=None):
        super().__init__(parent)
        self.tm = tm
        self._build()

    def _build(self):
        scroll = QScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setSpacing(16)
        layout.setContentsMargins(20, 20, 20, 20)

        # ── Colores ─────────────────────────────────────────
        grp_colors = QGroupBox("🎨 Colores")
        cl = QVBoxLayout(grp_colors)

        colors = self.tm.theme.get("colors", {})

        def make_color_row(label: str, key: str, default: str):
            row = QWidget()
            rl = QHBoxLayout(row)
            rl.setContentsMargins(0, 2, 0, 2)
            lbl = QLabel(label)
            lbl.setFixedWidth(200)
            rl.addWidget(lbl)
            btn = ColorButton(colors.get(key, default))
            btn.colorChanged.connect(
                lambda c, k=key: self._on_color_change(k, c)
            )
            rl.addWidget(btn)
            rl.addStretch()
            return row

        cl.addWidget(make_color_row("Borde Activo",   "col_active",   "#5999FF"))
        cl.addWidget(make_color_row("Borde Inactivo", "col_inactive", "#32324A"))
        cl.addWidget(make_color_row("Color Sombra",   "col_shadow",   "#00000080"))
        layout.addWidget(grp_colors)

        # ── Bordes & Esquinas ────────────────────────────────
        grp_borders = QGroupBox("◻️ Bordes & Esquinas")
        bl = QVBoxLayout(grp_borders)

        borders = self.tm.theme.get("borders", {})
        self.s_border = SliderRow("Grosor de borde", 0, 8,
                                  borders.get("border_size", 2), "px")
        self.s_rounding = SliderRow("Redondeo esquinas", 0, 24,
                                    borders.get("rounding", 10), "px")
        self.s_border.valueChanged.connect(
            lambda v: self._on_slider("border_size", "borders", v))
        self.s_rounding.valueChanged.connect(
            lambda v: self._on_slider("rounding", "borders", v))
        bl.addWidget(self.s_border)
        bl.addWidget(self.s_rounding)
        layout.addWidget(grp_borders)

        # ── Espaciado ────────────────────────────────────────
        grp_gaps = QGroupBox("↔️ Espaciado (Gaps)")
        gl = QVBoxLayout(grp_gaps)

        spacing = self.tm.theme.get("spacing", {})
        self.s_gaps_in  = SliderRow("Gaps internos",  0, 30,
                                    spacing.get("gaps_in", 5), "px")
        self.s_gaps_out = SliderRow("Gaps externos",  0, 50,
                                    spacing.get("gaps_out", 10), "px")
        self.s_gaps_in.valueChanged.connect(
            lambda v: self._on_slider("gaps_in", "spacing", v))
        self.s_gaps_out.valueChanged.connect(
            lambda v: self._on_slider("gaps_out", "spacing", v))
        gl.addWidget(self.s_gaps_in)
        gl.addWidget(self.s_gaps_out)
        layout.addWidget(grp_gaps)

        # ── Opacidad ─────────────────────────────────────────
        grp_opacity = QGroupBox("🌫️ Opacidad")
        ol = QVBoxLayout(grp_opacity)

        opacity = self.tm.theme.get("opacity", {})
        self.s_active_op = SliderRow("Ventana activa",   50, 100,
                                     int(opacity.get("active_opacity", 1.0)*100), "%")
        self.s_inactive_op = SliderRow("Ventana inactiva", 40, 100,
                                       int(opacity.get("inactive_opacity", 0.9)*100), "%")
        self.s_active_op.valueChanged.connect(
            lambda v: self._on_opacity("active_opacity", v))
        self.s_inactive_op.valueChanged.connect(
            lambda v: self._on_opacity("inactive_opacity", v))
        ol.addWidget(self.s_active_op)
        ol.addWidget(self.s_inactive_op)
        layout.addWidget(grp_opacity)

        # ── Botones de acción ────────────────────────────────
        btn_row = QHBoxLayout()
        btn_save = QPushButton("💾 Guardar Tema")
        btn_save.setObjectName("btnAccent")
        btn_save.clicked.connect(self._save)

        btn_reset = QPushButton("↺ Restablecer")
        btn_reset.clicked.connect(self._reset)

        btn_row.addWidget(btn_reset)
        btn_row.addStretch()
        btn_row.addWidget(btn_save)
        layout.addLayout(btn_row)
        layout.addStretch()

        scroll.setWidget(container)
        main = QVBoxLayout(self)
        main.addWidget(scroll)

    def _on_color_change(self, key: str, color: str):
        if "colors" not in self.tm.theme:
            self.tm.theme["colors"] = {}
        self.tm.theme["colors"][key] = color
        self.tm.apply_live(key, color)

    def _on_slider(self, key: str, section: str, value: int):
        if section not in self.tm.theme:
            self.tm.theme[section] = {}
        self.tm.theme[section][key] = value
        self.tm.apply_live(key, value)

    def _on_opacity(self, key: str, value: int):
        if "opacity" not in self.tm.theme:
            self.tm.theme["opacity"] = {}
        fval = value / 100.0
        self.tm.theme["opacity"][key] = fval
        self.tm.apply_live(key, fval)

    def _save(self):
        self.tm.save()

    def _reset(self):
        self.tm.theme = self.tm._defaults()
        self.tm.save()
        Hyprctl.reload()


# ─── Profiles Tab ────────────────────────────────────────────────────────────
class ProfilesTab(QWidget):
    def __init__(self, tm: ThemeManager, parent=None):
        super().__init__(parent)
        self.tm = tm
        self._build()

    def _build(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(20)

        title = QLabel("Selecciona el perfil de rendimiento:")
        title.setStyleSheet("font-size: 15px; color: #c8c8e0; margin-bottom: 8px;")
        layout.addWidget(title)

        profiles = [
            ("lite",   "btnLite",   "⚡ SUPER LITE",
             "Sin animaciones · Sin blur · Sin sombras\nConsumo de batería ultra bajo. Ideal para trabajo o viajes.",
             "#4aaa4a"),
            ("normal", "btnNormal", "⚖️ NORMAL",
             "Animaciones suaves · Blur ligero · Sombras\nEquilibrio entre rendimiento y experiencia visual.",
             "#5999ff"),
            ("full",   "btnFull",   "✨ FULL EXPERIENCE",
             "Blur intenso · Animaciones elaboradas · Widgets\nExperiencia visual completa. Requiere GPU dedicada.",
             "#aa55ff"),
        ]

        current = self.tm.theme.get("profile", "normal")
        self.profile_btns = {}

        for pid, obj_name, label, desc, color in profiles:
            card = QGroupBox()
            card.setStyleSheet(f"""
                QGroupBox {{
                    background: #13142a;
                    border: 1px solid #2a2b3d;
                    border-radius: 12px;
                    padding: 16px;
                    margin-top: 0px;
                }}
            """)
            cl = QHBoxLayout(card)

            # Indicador de color
            dot = QLabel("●")
            dot.setStyleSheet(f"color: {color}; font-size: 22px;")
            dot.setFixedWidth(32)
            cl.addWidget(dot)

            # Texto
            text_col = QVBoxLayout()
            lbl_title = QLabel(label)
            lbl_title.setStyleSheet(f"color: {color}; font-size: 15px; font-weight: 700;")
            lbl_desc = QLabel(desc)
            lbl_desc.setStyleSheet("color: #888899; font-size: 12px;")
            lbl_desc.setWordWrap(True)
            text_col.addWidget(lbl_title)
            text_col.addWidget(lbl_desc)
            cl.addLayout(text_col, 1)

            # Botón
            btn = QPushButton("✓ Activo" if pid == current else "Activar")
            btn.setObjectName(obj_name)
            btn.setFixedWidth(110)
            if pid == current:
                btn.setObjectName(obj_name)
                btn.setEnabled(False)
                btn.setStyleSheet(btn.styleSheet() + "opacity: 0.7;")
            btn.clicked.connect(lambda checked, p=pid: self._set_profile(p))
            self.profile_btns[pid] = btn
            cl.addWidget(btn)

            layout.addWidget(card)

        layout.addStretch()

        # Estado actual
        status_row = QHBoxLayout()
        self.lbl_status = QLabel(f"Perfil activo: {current.upper()}")
        self.lbl_status.setStyleSheet("color: #5999ff; font-weight: 700; font-size: 13px;")
        status_row.addWidget(self.lbl_status)
        status_row.addStretch()

        btn_reload = QPushButton("🔄 Recargar Hyprland")
        btn_reload.clicked.connect(lambda: Hyprctl.reload())
        status_row.addWidget(btn_reload)
        layout.addLayout(status_row)

    def _set_profile(self, profile_id: str):
        self.tm.set_profile(profile_id)
        self.lbl_status.setText(f"Perfil activo: {profile_id.upper()}")

        names = {"lite": "btnLite", "normal": "btnNormal", "full": "btnFull"}
        labels = {"lite": "⚡ SUPER LITE", "normal": "⚖️ NORMAL", "full": "✨ FULL"}

        for pid, btn in self.profile_btns.items():
            btn.setEnabled(pid != profile_id)
            btn.setText("✓ Activo" if pid == profile_id else "Activar")


# ─── Keybinds Tab ────────────────────────────────────────────────────────────
DEFAULT_BINDS = [
    ("SUPER", "Return",  "exec", "kitty",                "Abrir terminal"),
    ("SUPER", "Q",       "killactive", "",                "Cerrar ventana"),
    ("SUPER", "Space",   "exec", "wofi --show drun",      "Lanzador de apps"),
    ("SUPER", "E",       "exec", "thunar",                "Explorador de archivos"),
    ("SUPER", "V",       "togglefloating", "",            "Ventana flotante"),
    ("SUPER+SHIFT", "C", "exec", "hyprarch-control",      "Centro de Control"),
    ("SUPER", "S",       "togglespecialworkspace", "magic","Scratchpad"),
    ("",     "Print",    "exec", "grim -g \"$(slurp)\"",  "Captura de área"),
]

class KeybindsTab(QWidget):
    def __init__(self, tm: ThemeManager, parent=None):
        super().__init__(parent)
        self.tm = tm
        self._build()

    def _build(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        info = QLabel("Edita los atajos de teclado. Los cambios se guardan en user_binds.lua")
        info.setStyleSheet("color: #888899; font-size: 12px;")
        layout.addWidget(info)

        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels(["Modificador", "Tecla", "Acción", "Argumento", "Descripción"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(True)

        self._load_binds()
        layout.addWidget(self.table, 1)

        btn_row = QHBoxLayout()

        btn_add = QPushButton("➕ Añadir")
        btn_add.clicked.connect(self._add_row)

        btn_del = QPushButton("🗑️ Eliminar")
        btn_del.clicked.connect(self._del_row)

        btn_save = QPushButton("💾 Guardar Atajos")
        btn_save.setObjectName("btnAccent")
        btn_save.clicked.connect(self._save_binds)

        btn_row.addWidget(btn_add)
        btn_row.addWidget(btn_del)
        btn_row.addStretch()
        btn_row.addWidget(btn_save)
        layout.addLayout(btn_row)

    def _load_binds(self):
        self.table.setRowCount(0)
        binds = self._parse_binds_lua()
        if not binds:
            binds = DEFAULT_BINDS

        for row_data in binds:
            self._insert_row(row_data)

    def _parse_binds_lua(self):
        if not BINDS_LUA.exists():
            return None
        try:
            binds = []
            with open(BINDS_LUA) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("--") or not line:
                        continue
                    # Simple parse: { "MOD", "KEY", "action", "arg", "-- desc" }
                    parts = [p.strip().strip('"').strip("'") for p in
                             line.strip("{}").split(",")]
                    if len(parts) >= 4:
                        desc = ""
                        if "--" in (parts[4] if len(parts) > 4 else ""):
                            desc = parts[4].split("--")[-1].strip()
                        binds.append((parts[0], parts[1], parts[2],
                                      parts[3] if len(parts) > 3 else "",
                                      desc))
            return binds if binds else None
        except Exception:
            return None

    def _insert_row(self, data: tuple):
        row = self.table.rowCount()
        self.table.insertRow(row)
        for col, val in enumerate(data[:5]):
            item = QTableWidgetItem(str(val))
            self.table.setItem(row, col, item)

    def _add_row(self):
        self._insert_row(("SUPER", "KEY", "exec", "app", "Nueva acción"))

    def _del_row(self):
        rows = set(idx.row() for idx in self.table.selectedIndexes())
        for row in sorted(rows, reverse=True):
            self.table.removeRow(row)

    def _save_binds(self):
        lines = ["-- user_binds.lua — Generado por HyprArch Control Center\n",
                 "-- NO editar manualmente.\n\n",
                 "bind = bind or {}\n\n"]

        for row in range(self.table.rowCount()):
            cells = [self.table.item(row, col) for col in range(5)]
            values = [c.text() if c else "" for c in cells]
            mod, key, action, arg, desc = values
            lines.append(f'bind = {{ "{mod}", "{key}", "{action}", "{arg}" }}'
                         f'  -- {desc}\n')

        with open(BINDS_LUA, "w") as f:
            f.writelines(lines)

        Hyprctl.reload()


# ─── Presets Tab ─────────────────────────────────────────────────────────────
BUILTIN_PRESETS = {
    "Cyberpunk": {
        "colors": {"col_active": "#FF00FF", "col_inactive": "#002244",
                   "col_shadow": "#FF00FF44"},
        "borders": {"border_size": 1, "rounding": 4},
        "spacing": {"gaps_in": 3, "gaps_out": 6},
        "opacity": {"active_opacity": 1.0, "inactive_opacity": 0.85},
    },
    "Minimalist": {
        "colors": {"col_active": "#FFFFFF", "col_inactive": "#333333",
                   "col_shadow": "#00000000"},
        "borders": {"border_size": 1, "rounding": 0},
        "spacing": {"gaps_in": 4, "gaps_out": 8},
        "opacity": {"active_opacity": 1.0, "inactive_opacity": 1.0},
    },
    "Nord": {
        "colors": {"col_active": "#88C0D0", "col_inactive": "#3B4252",
                   "col_shadow": "#2E344080"},
        "borders": {"border_size": 2, "rounding": 8},
        "spacing": {"gaps_in": 5, "gaps_out": 10},
        "opacity": {"active_opacity": 1.0, "inactive_opacity": 0.92},
    },
    "Gruvbox": {
        "colors": {"col_active": "#D79921", "col_inactive": "#3C3836",
                   "col_shadow": "#28282880"},
        "borders": {"border_size": 2, "rounding": 6},
        "spacing": {"gaps_in": 4, "gaps_out": 8},
        "opacity": {"active_opacity": 1.0, "inactive_opacity": 0.90},
    },
    "Catppuccin": {
        "colors": {"col_active": "#CBA6F7", "col_inactive": "#313244",
                   "col_shadow": "#1E1E2E80"},
        "borders": {"border_size": 2, "rounding": 12},
        "spacing": {"gaps_in": 5, "gaps_out": 10},
        "opacity": {"active_opacity": 1.0, "inactive_opacity": 0.88},
    },
}

class PresetsTab(QWidget):
    def __init__(self, tm: ThemeManager, parent=None):
        super().__init__(parent)
        self.tm = tm
        self._build()

    def _build(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        title = QLabel("Presets de Comunidad")
        title.setStyleSheet("font-size: 16px; font-weight: 700; color: #c8c8e0;")
        layout.addWidget(title)

        info = QLabel("Aplica un preset completo al entorno visual con un solo clic.")
        info.setStyleSheet("color: #888899; font-size: 12px;")
        layout.addWidget(info)

        grid = QWidget()
        gl = QVBoxLayout(grid)
        gl.setSpacing(10)

        preset_icons = {
            "Cyberpunk": "🌆", "Minimalist": "⬜", "Nord": "❄️",
            "Gruvbox": "🍂", "Catppuccin": "🌸",
        }

        for name, cfg in BUILTIN_PRESETS.items():
            card = QWidget()
            card.setStyleSheet("""
                QWidget {
                    background: #13142a;
                    border: 1px solid #2a2b3d;
                    border-radius: 10px;
                }
            """)
            cl = QHBoxLayout(card)
            cl.setContentsMargins(16, 12, 16, 12)

            icon = QLabel(preset_icons.get(name, "🎨"))
            icon.setStyleSheet("font-size: 24px; background: transparent; border: none;")
            icon.setFixedWidth(40)
            cl.addWidget(icon)

            txt = QVBoxLayout()
            lbl_n = QLabel(name)
            lbl_n.setStyleSheet("font-size: 14px; font-weight: 700; color: #e0e0ff; background: transparent; border: none;")
            accent = cfg["colors"]["col_active"]
            lbl_c = QLabel(f"Borde: {accent}")
            lbl_c.setStyleSheet(f"font-size: 11px; color: {accent}; background: transparent; border: none;")
            txt.addWidget(lbl_n)
            txt.addWidget(lbl_c)
            cl.addLayout(txt, 1)

            btn = QPushButton("Aplicar")
            btn.setFixedWidth(90)
            btn.clicked.connect(lambda _, n=name, c=cfg: self._apply(n, c))
            cl.addWidget(btn)

            gl.addWidget(card)

        layout.addWidget(grid)
        layout.addStretch()

    def _apply(self, name: str, cfg: dict):
        self.tm.theme.update(cfg)
        self.tm.save()
        Hyprctl.batch([
            ("general:col.active_border",  ThemeManager._to_hypr_color(
                cfg["colors"]["col_active"])),
            ("general:border_size",         str(cfg["borders"]["border_size"])),
            ("decoration:rounding",         str(cfg["borders"]["rounding"])),
            ("general:gaps_in",             str(cfg["spacing"]["gaps_in"])),
            ("general:gaps_out",            str(cfg["spacing"]["gaps_out"])),
        ])


# ─── System Info Tab ──────────────────────────────────────────────────────────
class SystemTab(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._build()
        QTimer(self, timeout=self._refresh, interval=2000).start()

    def _build(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        grp = QGroupBox("📊 Sistema en Tiempo Real")
        gl = QVBoxLayout(grp)

        self.labels = {}
        rows = [
            ("cpu",    "CPU"),
            ("mem",    "Memoria RAM"),
            ("disk",   "Disco /"),
            ("gpu",    "GPU (Hyprland)"),
            ("ws",     "Workspaces Activos"),
        ]

        for key, label in rows:
            row = QHBoxLayout()
            lbl = QLabel(label + ":")
            lbl.setFixedWidth(160)
            val = QLabel("…")
            val.setStyleSheet("color: #5999ff; font-weight: 600;")
            row.addWidget(lbl)
            row.addWidget(val)
            row.addStretch()
            gl.addLayout(row)
            self.labels[key] = val

        layout.addWidget(grp)

        grp_cmds = QGroupBox("⚙️ Comandos Rápidos")
        cmdl = QVBoxLayout(grp_cmds)

        commands = [
            ("🔄 Recargar Hyprland",  lambda: Hyprctl.reload()),
            ("🖥️ Información de monitores", lambda: self._run("hyprctl monitors")),
            ("🪟 Ver ventanas activas",     lambda: self._run("hyprctl clients")),
            ("🔑 Ver atajos activos",       lambda: self._run("hyprctl binds")),
        ]

        for label, fn in commands:
            btn = QPushButton(label)
            btn.clicked.connect(fn)
            cmdl.addWidget(btn)

        layout.addWidget(grp_cmds)

        self.output_box = QLabel("")
        self.output_box.setStyleSheet("""
            background: #0a0b18;
            color: #66ff88;
            font-family: monospace;
            font-size: 11px;
            border: 1px solid #2a2b3d;
            border-radius: 6px;
            padding: 10px;
        """)
        self.output_box.setWordWrap(True)
        self.output_box.setTextInteractionFlags(
            Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(self.output_box, 1)

    def _refresh(self):
        try:
            import psutil
            cpu = psutil.cpu_percent(interval=None)
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage("/")
            self.labels["cpu"].setText(f"{cpu:.1f}%")
            self.labels["mem"].setText(
                f"{mem.used/1e9:.1f} / {mem.total/1e9:.1f} GB ({mem.percent:.0f}%)")
            self.labels["disk"].setText(
                f"{disk.used/1e9:.1f} / {disk.total/1e9:.1f} GB ({disk.percent:.0f}%)")
        except ImportError:
            self.labels["cpu"].setText("instala python-psutil")

        # Workspaces via hyprctl
        try:
            r = subprocess.run(["hyprctl", "workspaces", "-j"],
                               capture_output=True, text=True, timeout=1)
            ws = json.loads(r.stdout)
            active = [str(w.get("id")) for w in ws if w.get("windows", 0) > 0]
            self.labels["ws"].setText(", ".join(active) or "—")
            self.labels["gpu"].setText("Hyprland activo ✓")
        except Exception:
            self.labels["ws"].setText("N/A")
            self.labels["gpu"].setText("N/A")

    def _run(self, cmd: str):
        try:
            r = subprocess.run(cmd.split(), capture_output=True, text=True, timeout=3)
            out = r.stdout[:1200] + ("…" if len(r.stdout) > 1200 else "")
            self.output_box.setText(out or r.stderr[:500])
        except Exception as e:
            self.output_box.setText(str(e))


# ─── Main Window ─────────────────────────────────────────────────────────────
class HyprArchControl(QMainWindow):
    def __init__(self, tray_mode: bool = False):
        super().__init__()
        self.tm = ThemeManager()
        self.tray_mode = tray_mode
        self._build()
        if tray_mode:
            self._setup_tray()
            self.hide()

    def _build(self):
        self.setWindowTitle("HyprArch Control Center")
        self.setMinimumSize(860, 600)
        self.setObjectName("central")

        # Header
        header = QWidget()
        header.setFixedHeight(72)
        header.setStyleSheet("""
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 #0d0e1a, stop:0.5 #13142a, stop:1 #0d0e1a);
            border-bottom: 1px solid #2a2b3d;
        """)
        hl = QHBoxLayout(header)
        hl.setContentsMargins(24, 0, 24, 0)

        logo = QLabel("⬡ HyprArch")
        logo.setStyleSheet("color: #5999ff; font-size: 20px; font-weight: 800; letter-spacing: 2px;")
        hl.addWidget(logo)

        sub = QLabel("Control Center v2.0")
        sub.setStyleSheet("color: #555577; font-size: 12px; margin-left: 12px;")
        hl.addWidget(sub)
        hl.addStretch()

        # Profile badge
        p = self.tm.theme.get("profile", "normal")
        badge = QLabel({"lite": "⚡ LITE", "normal": "⚖️ NORMAL", "full": "✨ FULL"}.get(p, p.upper()))
        badge.setStyleSheet("""
            background: #1c1d36;
            color: #5999ff;
            font-size: 11px;
            font-weight: 700;
            padding: 4px 12px;
            border-radius: 12px;
            border: 1px solid #3a3b5a;
        """)
        hl.addWidget(badge)

        # Tabs
        tabs = QTabWidget()
        tabs.addTab(VisualTab(self.tm),   "🎨  Visual")
        tabs.addTab(ProfilesTab(self.tm), "⚡  Perfiles")
        tabs.addTab(KeybindsTab(self.tm), "⌨️   Atajos")
        tabs.addTab(PresetsTab(self.tm),  "🌐  Presets")
        tabs.addTab(SystemTab(),          "📊  Sistema")

        central = QWidget()
        cl = QVBoxLayout(central)
        cl.setContentsMargins(0, 0, 0, 0)
        cl.setSpacing(0)
        cl.addWidget(header)
        cl.addWidget(tabs)

        self.setCentralWidget(central)

    def _setup_tray(self):
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return

        self.tray = QSystemTrayIcon(self)
        # Simple colored icon
        px = QPixmap(22, 22)
        px.fill(QColor("#5999ff"))
        self.tray.setIcon(QIcon(px))

        menu = QMenu()
        menu.addAction("Abrir Centro de Control", self.show)
        menu.addSeparator()
        menu.addAction("⚡ Perfil Lite",   lambda: self.tm.set_profile("lite"))
        menu.addAction("⚖️ Perfil Normal", lambda: self.tm.set_profile("normal"))
        menu.addAction("✨ Perfil Full",   lambda: self.tm.set_profile("full"))
        menu.addSeparator()
        menu.addAction("🔄 Recargar Hyprland", Hyprctl.reload)
        menu.addSeparator()
        menu.addAction("Salir", QApplication.quit)

        self.tray.setContextMenu(menu)
        self.tray.activated.connect(
            lambda r: self.show() if r == QSystemTrayIcon.ActivationReason.Trigger else None)
        self.tray.show()

    def closeEvent(self, event):
        if self.tray_mode and hasattr(self, "tray"):
            event.ignore()
            self.hide()
        else:
            event.accept()


# ─── Entry Point ─────────────────────────────────────────────────────────────
def main():
    import argparse
    parser = argparse.ArgumentParser(description="HyprArch Control Center")
    parser.add_argument("--tray", action="store_true",
                        help="Iniciar minimizado en el system tray")
    parser.add_argument("--profile", choices=["lite", "normal", "full"],
                        help="Cambiar perfil desde CLI")
    args = parser.parse_args()

    # CLI profile switch sin GUI
    if args.profile:
        tm = ThemeManager()
        tm.set_profile(args.profile)
        print(f"Perfil '{args.profile}' aplicado.")
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setApplicationName("HyprArch Control Center")
    app.setStyleSheet(STYLE)

    # Use system font stack
    font = QFont("Noto Sans", 11)
    app.setFont(font)

    window = HyprArchControl(tray_mode=args.tray)
    if not args.tray:
        window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
