package com.cybercircuit.client;

import java.util.ArrayList;
import java.util.List;

public final class CyberCircuitModules {
    private static final List<CyberCircuitModule> MODULES = new ArrayList<>(List.of(
        new CyberCircuitModule("Baritone", "Automation", "Pathfinding, navigation and schematic building. Installed as a companion Fabric mod.", true, true),
        new CyberCircuitModule("Wurst", "Hacks", "Wurst 7.55.1 companion client. Its own ClickGUI controls the actual hack modules.", true, true),
        new CyberCircuitModule("Keystrokes", "HUD", "Displays movement and mouse keys in an in-game overlay.", false, false),
        new CyberCircuitModule("CPS", "HUD", "Displays left and right clicks per second.", false, false),
        new CyberCircuitModule("FPS", "HUD", "Displays current frames per second.", false, true),
        new CyberCircuitModule("Coordinates", "HUD", "Displays your current X, Y and Z coordinates.", false, false),
        new CyberCircuitModule("Hitboxes", "Render", "Highlights entity hitboxes for easier visual tracking.", false, false),
        new CyberCircuitModule("Fullbright", "Render", "Provides a client-side brightness mode when implemented by the selected profile.", false, false),
        new CyberCircuitModule("Zoom", "Render", "A client-side zoom control for inspecting distant builds.", false, false),
        new CyberCircuitModule("Auto Tool", "Player", "Client-side tool selection helper.", false, false),
        new CyberCircuitModule("Toggle Sprint", "Movement", "Keeps sprint enabled while movement conditions allow it.", false, false),
        new CyberCircuitModule("Schematic Builder", "Automation", "Quick access to Baritone schematic building guidance.", true, true),
        new CyberCircuitModule("Ping", "HUD", "Displays current server latency. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Armor HUD", "HUD", "Displays armor and held-item durability. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Potion HUD", "HUD", "Displays active effects and timers. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Clock", "HUD", "Displays real-world or in-game time. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Memory / CPU HUD", "HUD", "Shows client memory and CPU usage information. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Session Info", "HUD", "Displays session time and gameplay statistics. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Crosshair Editor", "Render", "Customize crosshair shape, size and gap. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Low Fire", "Render", "Reduces the size of the fire overlay. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Hit Color", "Combat", "Visual feedback when hitting an entity. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Attack Indicator", "Combat", "Configurable attack cooldown indicator. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Reach Display", "Combat", "Informational display of attack distance. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Totem Counter", "Combat", "Displays totems currently available. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Inventory / Hotbar HUD", "HUD", "Displays inventory or hotbar information on-screen. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Combat Info Panel", "Combat", "Displays selected target and combat information. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Toggle Sneak", "Movement", "Keeps sneak enabled while movement conditions allow it. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("FOV Modifier", "Render", "Controls field-of-view changes from movement and effects. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Speedometer", "Movement", "Displays current player movement speed. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Jump / Movement Statistics", "Movement", "Tracks jump and movement statistics. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Waypoints", "World", "Create and display saved world locations. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Minimap", "World", "Displays a compact configurable world map. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Entity ESP", "Render", "Highlights selected entity types. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Block ESP", "Render", "Highlights selected blocks. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Light Level Overlay", "World", "Shows block light levels for building and spawn-proofing. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Chunk Borders", "World", "Displays chunk boundaries. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Structure Locator UI", "World", "Provides a client-side structure information panel. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Biome Display", "World", "Displays the current biome. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Durability Warnings", "Player", "Warns when equipped items are getting low on durability. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Schematic Browser", "Automation", "Browse available schematic files before building. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Build Progress HUD", "Automation", "Displays schematic building progress. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Path Preview", "Automation", "Shows a preview of an automation path. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Auto-Reconnect", "Utility", "Reconnects after a supported disconnect condition. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("AFK Protection / Status", "Utility", "Shows AFK state and protection status. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("ClickGUI", "Client", "Open and configure CyberCircuit modules through a compact GUI. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("HUD Editor", "Client", "Drag HUD modules around the screen and save their positions. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("GUI Scale Controls", "Client", "Quick controls for client GUI scale. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Custom Themes", "Client", "Switch CyberCircuit visual themes. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Custom Fonts", "Client", "Select a supported client font. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Module Profiles", "Client", "Save PvP, Building, SMP and custom module layouts. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Config Import / Export", "Client", "Import and export CyberCircuit configurations. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Keybind Editor", "Client", "Configure module keybinds. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("FPS Limiter", "Performance", "Configure a client-side frame-rate limit. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Entity Render Distance", "Performance", "Adjust client-side entity rendering distance. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Particle Controls", "Performance", "Control client particle density. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Animation Controls", "Performance", "Control selected client animations. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Dynamic Render Distance", "Performance", "Adjust render distance using a performance profile. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Performance Monitor", "Performance", "Display frame and rendering performance information. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Memory Status", "Performance", "Display Java memory allocation and usage. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Fast Menu", "Performance", "Reduce optional GUI animation and menu overhead. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Inventory Search", "Player", "Search visible inventory slots quickly. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Item Info Overlay", "HUD", "Displays selected item information. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Chat Cleaner", "Utility", "Optional client-side chat filtering and formatting. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Chat Timestamps", "HUD", "Adds timestamps to client chat messages. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Nameplate HUD", "Render", "Customizes selected entity nameplates. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Damage Indicators", "Combat", "Displays optional damage feedback. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Target HUD", "Combat", "Displays information for the selected combat target. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Item Cooldowns", "HUD", "Displays cooldown information for selected items. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Quick Recipe Access", "Player", "Provides quick access to supported recipes. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Screenshot Tools", "Utility", "Adds client-side screenshot organization controls. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Mod Search", "Client", "Search and filter the CyberCircuit module catalog. Planned for CyberCircuit v26 feature development.", false, false),
        new CyberCircuitModule("Debug Overlay", "HUD", "Compact technical information overlay for troubleshooting. Planned for CyberCircuit v26 feature development.", false, false)
    ));

    private CyberCircuitModules() {}

    public static List<CyberCircuitModule> all() {
        return List.copyOf(MODULES);
    }

    public static List<String> categories() {
        return List.of("All", "Hacks", "Combat", "Movement", "Render", "Player", "Automation", "HUD", "World", "Utility", "Client", "Performance");
    }
}
