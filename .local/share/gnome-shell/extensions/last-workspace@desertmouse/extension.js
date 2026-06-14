import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import Shell from 'gi://Shell';

export default class LastWorkspaceExtension extends Extension {
    enable() {
        this._previousIndex = -1;
        this._currentIndex = global.workspace_manager.get_active_workspace_index();

        // Watch for workspace changes
        this._wsChangedId = global.workspace_manager.connect(
            'active-workspace-changed',
            () => {
                const newIndex = global.workspace_manager.get_active_workspace_index();
                this._previousIndex = this._currentIndex;
                this._currentIndex = newIndex;
            }
        );

        // Register the keybinding (configured in settings)
        Main.wm.addKeybinding(
            'switch-to-previous-workspace',
            this.getSettings('org.gnome.shell.extensions.last-workspace'),
            0, // no MetaKeyBindingFlags
            Shell.ActionMode.NORMAL,
            () => this._switchToPrevious()
        );
    }

    disable() {
        if (this._wsChangedId) {
            global.workspace_manager.disconnect(this._wsChangedId);
            this._wsChangedId = null;
        }
        Main.wm.removeKeybinding('switch-to-previous-workspace');
        this._previousIndex = -1;
        this._currentIndex = -1;
    }

    _switchToPrevious() {
        if (this._previousIndex < 0) return;

        const ws = global.workspace_manager.get_workspace_by_index(this._previousIndex);
        if (ws) {
            ws.activate(global.get_current_time());
        }
    }
}
