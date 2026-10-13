package com.cybercircuit.client;

import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;

import java.util.List;

/** Modern CyberCircuit module manager for Minecraft 26.2. */
public final class CyberCircuitScreen extends Screen {
    private static final int BG = 0xF5060A10;
    private static final int HEADER = 0xF50B111A;
    private static final int PANEL = 0xF5111822;
    private static final int PANEL_2 = 0xF518202C;
    private static final int PANEL_3 = 0xF51D2734;
    private static final int ACCENT = 0xFF43C7FF;
    private static final int TEXT = 0xFFF4F7FA;
    private static final int MUTED = 0xFF98A5B5;
    private static final int ON = 0xFF43D47B;
    private static final int WARN = 0xFFFFC04D;

    private String category = "All";
    private String selected = "FPS";
    private String message = "Choose a module.";

    public CyberCircuitScreen() {
        super(Component.literal("CyberCircuit Client"));
    }

    @Override
    protected void init() {
        buildWidgets();
    }

    private void buildWidgets() {
        clearWidgets();

        final int margin = 18;
        final int headerH = 58;
        final int sidebarW = 168;
        final int gap = 12;
        final int detailsW = Math.min(300, Math.max(250, width / 4));
        final int contentX = margin + sidebarW + gap;
        final int contentW = Math.max(360, width - contentX - margin - detailsW - gap);
        final int detailsX = contentX + contentW + gap;
        final int panelTop = headerH + 12;
        final int panelBottom = height - 42;

        int y = panelTop + 16;
        for (String cat : CyberCircuitModules.categories()) {
            final String chosen = cat;
            Button b = Button.builder(Component.literal(chosen), button -> {
                category = chosen;
                selected = filteredModules().isEmpty() ? selected : filteredModules().get(0).name();
                message = chosen + " modules";
                buildWidgets();
            }).bounds(margin + 10, y, sidebarW - 20, 28).build();
            addRenderableWidget(b);
            y += 34;
        }

        List<CyberCircuitModule> visible = filteredModules();
        int rowY = panelTop + 42;
        int rowH = 34;
        int maxRows = Math.max(1, (panelBottom - rowY - 8) / 40);
        int count = Math.min(visible.size(), maxRows);
        for (int i = 0; i < count; i++) {
            CyberCircuitModule module = visible.get(i);
            final String name = module.name();
            Button b = Button.builder(Component.literal(name), button -> {
                selected = name;
                message = name + " selected";
                buildWidgets();
            }).bounds(contentX + 10, rowY + i * 40, contentW - 20, rowH).build();
            addRenderableWidget(b);
        }

        CyberCircuitModule current = findSelected();
        Button action = Button.builder(Component.literal(current.external() ? "COMPANION MOD" : (current.enabled() ? "ENABLED" : "DISABLED")), b -> {
            if (current.external()) message = current.name() + " is managed by its companion mod.";
            else message = current.name() + " is controlled by the desktop launcher profile.";
        }).bounds(detailsX + 14, panelTop + 174, detailsW - 28, 32).build();
        addRenderableWidget(action);

        Button schematic = Button.builder(Component.literal("SCHEMATIC HELP"), b -> message = "Baritone: use #build <name> after placing your schematic in the schematics folder.")
            .bounds(detailsX + 14, panelTop + 214, detailsW - 28, 32).build();
        addRenderableWidget(schematic);

        Button close = Button.builder(Component.literal("CLOSE"), b -> this.minecraft.gui.setScreen(null))
            .bounds(detailsX + 14, panelBottom - 42, detailsW - 28, 32).build();
        addRenderableWidget(close);
    }

    private List<CyberCircuitModule> filteredModules() {
        if ("All".equals(category)) return CyberCircuitModules.all();
        return CyberCircuitModules.all().stream().filter(m -> m.category().equals(category)).toList();
    }

    private CyberCircuitModule findSelected() {
        for (CyberCircuitModule m : CyberCircuitModules.all()) if (m.name().equals(selected)) return m;
        return CyberCircuitModules.all().get(0);
    }

    @Override
    public void extractRenderState(GuiGraphicsExtractor graphics, int mouseX, int mouseY, float delta) {
        super.extractRenderState(graphics, mouseX, mouseY, delta);

        final int margin = 18;
        final int headerH = 58;
        final int sidebarW = 168;
        final int gap = 12;
        final int detailsW = Math.min(300, Math.max(250, width / 4));
        final int contentX = margin + sidebarW + gap;
        final int contentW = Math.max(360, width - contentX - margin - detailsW - gap);
        final int detailsX = contentX + contentW + gap;
        final int panelTop = headerH + 12;
        final int panelBottom = height - 42;

        graphics.fill(0, 0, width, height, BG);
        graphics.fill(0, 0, width, headerH, HEADER);
        graphics.fill(margin, 12, margin + 4, headerH - 10, ACCENT);
        graphics.text(font, "CYBERCIRCUIT", margin + 16, 17, TEXT, true);
        graphics.text(font, "CLIENT  /  MINECRAFT 26.2", margin + 16, 36, MUTED, false);
        graphics.text(font, "RIGHT SHIFT", width - 100, 24, ACCENT, true);

        graphics.fill(margin, panelTop, margin + sidebarW, panelBottom, PANEL);
        graphics.text(font, "CATEGORIES", margin + 12, panelTop + 8, MUTED, true);
        int catY = panelTop + 16;
        for (String cat : CyberCircuitModules.categories()) {
            if (cat.equals(category)) graphics.fill(margin + 8, catY - 3, margin + sidebarW - 8, catY + 27, PANEL_3);
            graphics.text(font, cat, margin + 20, catY + 6, cat.equals(category) ? ACCENT : TEXT, cat.equals(category));
            catY += 34;
        }

        graphics.fill(contentX, panelTop, contentX + contentW, panelBottom, PANEL);
        graphics.text(font, "MODULES", contentX + 14, panelTop + 12, TEXT, true);
        graphics.text(font, category.toUpperCase(), contentX + contentW - 78, panelTop + 12, MUTED, false);
        List<CyberCircuitModule> visible = filteredModules();
        int rowY = panelTop + 42;
        int rowH = 34;
        int maxRows = Math.max(1, (panelBottom - rowY - 8) / 40);
        for (int i = 0; i < Math.min(visible.size(), maxRows); i++) {
            CyberCircuitModule m = visible.get(i);
            int y = rowY + i * 40;
            boolean isSelected = m.name().equals(selected);
            graphics.fill(contentX + 10, y, contentX + contentW - 10, y + rowH, isSelected ? PANEL_3 : 0xF40D141D);
            graphics.text(font, m.name(), contentX + 22, y + 7, isSelected ? ACCENT : TEXT, isSelected);
            graphics.text(font, m.external() ? "COMPANION" : "CLIENT", contentX + contentW - 82, y + 7, m.external() ? WARN : ON, false);
        }
        if (visible.size() > maxRows) graphics.text(font, "Scroll in the module list", contentX + 16, panelBottom - 18, MUTED, false);

        CyberCircuitModule current = findSelected();
        graphics.fill(detailsX, panelTop, detailsX + detailsW, panelBottom, PANEL);
        graphics.text(font, "SELECTED MODULE", detailsX + 14, panelTop + 14, MUTED, true);
        graphics.text(font, current.name(), detailsX + 14, panelTop + 44, TEXT, true);
        graphics.text(font, current.category(), detailsX + 14, panelTop + 68, ACCENT, false);
        drawWrapped(graphics, current.description(), detailsX + 14, panelTop + 94, detailsW - 28, MUTED);
        graphics.text(font, current.external() ? "COMPANION MOD" : (current.enabled() ? "ENABLED" : "DISABLED"), detailsX + 14, panelTop + 150, current.external() ? WARN : ON, true);

        if (message != null) graphics.text(font, message, margin + 2, height - 28, TEXT, false);
        graphics.text(font, "CyberCircuit Client  •  v26", width - 145, height - 28, MUTED, false);
    }

    private void drawWrapped(GuiGraphicsExtractor graphics, String text, int x, int y, int maxWidth, int color) {
        String[] words = text.split(" ");
        StringBuilder line = new StringBuilder();
        int currentY = y;
        for (String word : words) {
            String candidate = line.length() == 0 ? word : line + " " + word;
            if (font.width(candidate) > maxWidth && line.length() > 0) {
                graphics.text(font, line.toString(), x, currentY, color, false);
                currentY += 14;
                line.setLength(0);
            }
            if (line.length() > 0) line.append(' ');
            line.append(word);
        }
        if (line.length() > 0) graphics.text(font, line.toString(), x, currentY, color, false);
    }
}
