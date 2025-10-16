# Quick Fix: Reset Ollama Model to gemma3:27b

## Immediate Solution (Run in Godot Console)

Open the Godot editor console and run this **single line**:

```gdscript
Shoggoth.reset_config()
```

This will:
1. Delete your old config file (which has `mistral-small:24b`)
2. Create a new config with `gemma3:27b` as the default
3. Reinitialize Shoggoth with the new settings

## Alternative: Manually Change Model

If you want to change to a specific model without resetting all settings:

```gdscript
Shoggoth.set_model("gemma3:27b")
```

## Find Your Config File Location

To see where the config file is stored:

```gdscript
print(Shoggoth.get_config_file_path())
```

Then you can manually edit it with a text editor.

## After the Fix

Once your config is reset, the 404 errors should stop. The system will use `gemma3:27b` going forward.

---

## Long-term Solution: Admin UI

I've created a settings UI script at `UI/shoggoth_settings.gd`. To use it:

1. Create a new Window scene in Godot
2. Attach the `shoggoth_settings.gd` script
3. Add UI elements with these unique names (use % for unique names):
   - OptionButton: `%ModelDropdown`
   - LineEdit: `%HostInput`
   - HSlider: `%TemperatureSlider`
   - Label: `%TemperatureLabel`
   - Button: `%RefreshButton`
   - Button: `%TestButton`
   - Button: `%ApplyButton`
   - Label: `%StatusLabel`

This will give you a visual admin panel for Ollama configuration.
