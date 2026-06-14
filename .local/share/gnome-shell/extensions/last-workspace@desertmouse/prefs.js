// SPDX-FileCopyrightText: 2025 desertmouse
// SPDX-License-Identifier: GPL-3.0-or-later

import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import GObject from 'gi://GObject';
import Gtk from 'gi://Gtk';
import { ExtensionPreferences, gettext as _ } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const KeybindingRow = GObject.registerClass(
class KeybindingRow extends Adw.ActionRow {
    #label;
    #resetButton;
    #captureWindow;
    #settings;
    #key;

    constructor(settings, key, title, subtitle) {
        super({ title, subtitle, activatable: true });

        this.#settings = settings;
        this.#key = key;

        // Shortcut label
        this.#label = new Gtk.ShortcutLabel({
            disabled_text: _('Not set'),
            accelerator: settings.get_strv(key)[0] ?? '',
            valign: Gtk.Align.CENTER,
        });
        this.add_suffix(this.#label);

        // Reset button
        this.#resetButton = new Gtk.Button({
            icon_name: 'edit-delete-symbolic',
            css_classes: ['destructive-action'],
            valign: Gtk.Align.CENTER,
            visible: !!settings.get_strv(key)[0],
        });
        this.#resetButton.connect('clicked', () => this.#reset());
        this.add_suffix(this.#resetButton);

        // Label drives settings
        this.#label.connect('notify::accelerator', (widget) => {
            settings.set_strv(key, widget.accelerator ? [widget.accelerator] : []);
            this.#resetButton.visible = !!widget.accelerator;
        });

        // Keep label in sync if changed externally (e.g. via gsettings)
        settings.connect(`changed::${key}`, () => {
            this.#label.accelerator = settings.get_strv(key)[0] ?? '';
        });

        this.connect('activated', () => this.#openCaptureWindow());
    }

    #reset() {
        this.#label.accelerator = '';
    }

    #openCaptureWindow() {
        const content = new Adw.StatusPage({
            title: _('New Shortcut'),
            description: _('Press Escape to cancel, Backspace to clear'),
            icon_name: 'preferences-desktop-keyboard-shortcuts-symbolic',
        });

        this.#captureWindow = new Adw.Window({
            modal: true,
            transient_for: this.get_root(),
            width_request: 360,
            height_request: 240,
            resizable: false,
            content,
        });

        const controller = new Gtk.EventControllerKey();
        this.#captureWindow.add_controller(controller);
        controller.connect('key-pressed', this.#onKeyPressed.bind(this));

        this.#captureWindow.present();
    }

    #onKeyPressed(_controller, keyval, keycode, state) {
        let mask = state & Gtk.accelerator_get_default_mod_mask();
        mask &= ~Gdk.ModifierType.LOCK_MASK;

        if (!mask && keyval === Gdk.KEY_Escape) {
            this.#captureWindow.destroy();
            return Gdk.EVENT_STOP;
        }

        if (keyval === Gdk.KEY_BackSpace) {
            this.#reset();
            this.#captureWindow.destroy();
            return Gdk.EVENT_STOP;
        }

        if (!this.#isValidBinding(mask, keycode, keyval) || !this.#isValidAccel(mask, keyval))
            return Gdk.EVENT_STOP;

        this.#label.accelerator = Gtk.accelerator_name_with_keycode(null, keyval, keycode, mask);
        this.#captureWindow.destroy();
        return Gdk.EVENT_STOP;
    }

    #isValidBinding(mask, keycode, keyval) {
        if ((mask === 0 || mask === Gdk.ModifierType.SHIFT_MASK) && keycode !== 0) {
            if (
                this.#isKeyInRange(keyval, Gdk.KEY_a, Gdk.KEY_z) ||
                this.#isKeyInRange(keyval, Gdk.KEY_A, Gdk.KEY_Z) ||
                this.#isKeyInRange(keyval, Gdk.KEY_0, Gdk.KEY_9) ||
                this.#isKeyInRange(keyval, Gdk.KEY_kana_fullstop, Gdk.KEY_semivoicedsound) ||
                this.#isKeyInRange(keyval, Gdk.KEY_Arabic_comma, Gdk.KEY_Arabic_sukun) ||
                this.#isKeyInRange(keyval, Gdk.KEY_Serbian_dje, Gdk.KEY_Cyrillic_HARDSIGN) ||
                this.#isKeyInRange(keyval, Gdk.KEY_Greek_ALPHAaccent, Gdk.KEY_Greek_omega) ||
                this.#isKeyInRange(keyval, Gdk.KEY_hebrew_doublelowline, Gdk.KEY_hebrew_taf) ||
                this.#isKeyInRange(keyval, Gdk.KEY_Thai_kokai, Gdk.KEY_Thai_lekkao) ||
                this.#isKeyInRange(keyval, Gdk.KEY_Hangul_Kiyeog, Gdk.KEY_Hangul_J_YeorinHieuh) ||
                (keyval === Gdk.KEY_space && mask === 0) ||
                this.#isKeyvalForbidden(keyval)
            )
                return false;
        }
        return true;
    }

    #isKeyInRange(keyval, start, end) {
        return keyval >= start && keyval <= end;
    }

    #isKeyvalForbidden(keyval) {
        return [
            Gdk.KEY_Home, Gdk.KEY_Left, Gdk.KEY_Up, Gdk.KEY_Right, Gdk.KEY_Down,
            Gdk.KEY_Page_Up, Gdk.KEY_Page_Down, Gdk.KEY_End, Gdk.KEY_Tab,
            Gdk.KEY_KP_Enter, Gdk.KEY_Return, Gdk.KEY_Mode_switch,
        ].includes(keyval);
    }

    #isValidAccel(mask, keyval) {
        return Gtk.accelerator_valid(keyval, mask) || (keyval === Gdk.KEY_Tab && mask !== 0);
    }
});

export default class LastWorkspacePreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings('org.gnome.shell.extensions.last-workspace');

        const page = new Adw.PreferencesPage();
        const group = new Adw.PreferencesGroup({ title: _('Keyboard Shortcut') });
        page.add(group);

        group.add(new KeybindingRow(
            settings,
            'switch-to-previous-workspace',
            _('Switch to previous workspace'),
            _('Press the row to record a new shortcut'),
        ));

        window.add(page);
    }
}
