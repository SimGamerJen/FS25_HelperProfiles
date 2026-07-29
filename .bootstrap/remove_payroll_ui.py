from pathlib import Path
import hashlib
import re

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def write(path, text):
    (ROOT / path).write_text(text, encoding='utf-8')


def sub_once(pattern, replacement, text, label, flags=0):
    updated, count = re.subn(pattern, replacement, text, flags=flags)
    if count != 1:
        raise RuntimeError(f'{label}: expected one replacement, got {count}')
    return updated

# Keep HelperProfiles' appearance-binding screen appearance-only. HelperPayroll
# owns role assignment and worker compensation management.
path = 'scripts/gui/HP_AppearanceBindingsScreen.lua'
s = read(path)
s = sub_once(
    r'\nlocal function getPayrollAPI\(\).*?\nlocal function slotForIndex\(index\)',
    '\n\nlocal function slotForIndex(index)',
    s,
    'remove payroll API helpers',
    re.S,
)

for line in (
    '    self.payrollRoles = {}\n',
    '    self.draftPayrollRoles = {}\n',
    '    self.originalPayrollRoles = {}\n',
    '    self.payrollRoleChanges = {}\n',
    '    self.payrollRoleSources = {}\n',
    '    self.appearanceChangedSlots = {}\n',
    '    self.selectedPayrollRoleIndex = 1\n',
    '    self.payrollAvailable = false\n',
    '    self.payrollDetected = false\n',
    '    self.payrollMode = nil\n',
    '    self.payrollRetryElapsedMs = 0\n',
    '    self.payrollRetryAttempts = 0\n',
    '    self.payrollDirty = false\n',
):
    if line not in s:
        raise RuntimeError(f'missing constructor/state line: {line.strip()}')
    s = s.replace(line, '')

s = sub_once(
    r'    self\.dirty = self\.appearanceDirty == true or self\.payrollDirty == true\n',
    '    self.dirty = self.appearanceDirty == true\n',
    s,
    'appearance-only dirty state',
)

s = sub_once(
    r'\nfunction HP_AppearanceBindingsScreen:setVisibleSafe\(element, visible\).*?\nfunction HP_AppearanceBindingsScreen:onGuiSetupFinished\(\)',
    '\n\nfunction HP_AppearanceBindingsScreen:onGuiSetupFinished()',
    s,
    'remove payroll UI methods',
    re.S,
)

s = sub_once(
    r'    self:updatePayrollControls\(\)\nend\n\nfunction HP_AppearanceBindingsScreen:onCreate\(\)',
    'end\n\nfunction HP_AppearanceBindingsScreen:onCreate()',
    s,
    'remove GUI setup payroll update',
)

for line in ('    self.payrollRetryElapsedMs = 0\n', '    self.payrollRetryAttempts = 0\n'):
    if line not in s:
        raise RuntimeError(f'missing open retry line: {line.strip()}')
    s = s.replace(line, '')

s = sub_once(
    r'\nfunction HP_AppearanceBindingsScreen:update\(dt\).*?\nfunction HP_AppearanceBindingsScreen:onClose\(\)',
    '\n\nfunction HP_AppearanceBindingsScreen:onClose()',
    s,
    'remove payroll retry update',
    re.S,
)

for line in (
    '    self.payrollDirty = false\n',
    '    self.appearanceChangedSlots = {}\n',
    '    self:loadPayrollData()\n',
    '        self:syncPayrollSelectionFromDraft()\n',
    '        self:updatePayrollControls()\n',
):
    s = s.replace(line, '')

s = re.sub(r'\n    if helperRow\.slot ~= nil then self\.appearanceChangedSlots\[helperRow\.slot\] = true end', '', s)
s = re.sub(
    r'\n    for _, helperRow in ipairs\(self\.helperRows or \{\}\) do\n        if helperRow\.slot ~= nil then self\.appearanceChangedSlots\[helperRow\.slot\] = true end\n    end',
    '',
    s,
)
s = s.replace(
    'local detail = hpI18n("hp_detail_select", "Select a helper slot, appearance, and payroll role.")',
    'local detail = hpI18n("hp_detail_select", "Select a helper slot and appearance.")',
)

start = s.index('function HP_AppearanceBindingsScreen:saveBindings(closeAfterSave)')
end = s.index('\nfunction HP_AppearanceBindingsScreen:setStatus(text)', start)
new_save = '''function HP_AppearanceBindingsScreen:saveBindings(closeAfterSave)
    if self.dirty ~= true then
        self:setStatus(hpI18n("hp_status_ready", "Ready"))
        if closeAfterSave == true then self:close() end
        return true
    end

    if HP_ASBridge == nil or HP_ASBridge.replaceLinksSnapshot == nil then
        self:setStatus(hpI18n("hp_error_as_bridge_unavailable", "Save failed: AS bridge unavailable"))
        return false
    end

    local ok, err = HP_ASBridge:replaceLinksSnapshot(self.draftLinks or {})
    if not ok then
        self:setStatus(hpFormat("hp_error_save_failed", "Save failed: %s", tostring(err)))
        return false
    end

    self.appearanceDirty = false
    self:refreshDirtyState()
    if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.refreshActiveWorkers ~= nil then
        HP_WorkerAppearance:refreshActiveWorkers()
    end

    self.actionMessage = hpI18n("hp_status_bindings_saved", "Bindings saved. Active workers refreshed.")
    self:reloadData(true)
    if closeAfterSave == true then self:close() end
    return true
end
'''
s = s[:start] + new_save + s[end:]
write(path, s)

path = 'gui/HP_AppearanceBindingsScreen.xml'
s = read(path)
s = sub_once(
    r'\n\s*<GuiElement profile="hpPayrollRoleControls" id="payrollRoleControls".*?</GuiElement>',
    '',
    s,
    'remove payroll row XML',
    re.S,
)
write(path, s)

path = 'gui/guiProfiles.xml'
s = read(path)
s = sub_once(
    r'\n\s*<Profile name="hpPayrollRoleControls".*?</Profile>',
    '',
    s,
    'remove payroll row profile',
    re.S,
)
write(path, s)

remove_names = {
    'hp_payroll_role_label', 'hp_payroll_no_roles', 'hp_payroll_waiting',
    'hp_payroll_retry_context', 'hp_payroll_source', 'hp_payroll_context',
    'hp_status_draft_payroll_role', 'hp_error_payroll_api_unavailable',
    'hp_error_payroll_save_failed', 'hp_status_profile_changes_saved',
    'hp_status_payroll_roles_saved',
}
detail_text = {
    'l10n/l10n_en.xml': 'Select a helper slot and appearance.',
    'l10n/l10n_de.xml': 'Wähle einen Helfer-Slot und ein Erscheinungsbild.',
    'l10n/l10n_fr.xml': "Sélectionnez un emplacement d'aide et une apparence.",
}
for path, replacement in detail_text.items():
    s = read(path)
    for name in remove_names:
        s = re.sub(r'\n\s*<text name="' + re.escape(name) + r'"[^>]*/>', '', s)
    s, count = re.subn(
        r'(<text name="hp_detail_select" text=")[^"]*("/>)',
        lambda match: match.group(1) + replacement + match.group(2),
        s,
    )
    if count != 1:
        raise RuntimeError(f'{path}: hp_detail_select replacement count={count}')
    write(path, s)

path = 'modDesc.xml'
s = read(path)
replacements = {
    'and optional HelperPayroll role assignment for each helper profile on a per-savegame basis.': 'and optional read-only HelperPayroll role information in the roster overlay.',
    'und eine optionale HelperPayroll-Rollenzuweisung für jedes Helferprofil pro Spielstand.': 'und optionale, schreibgeschützte HelperPayroll-Rolleninformationen im Helfer-Overlay.',
    "et l'attribution optionnelle de rôles HelperPayroll à chaque profil d'aide pour chaque sauvegarde.": 'et l’affichage facultatif, en lecture seule, des rôles HelperPayroll dans la superposition des aides.',
    '- Fixed HelperPayroll role controls remaining hidden when the companion API was published after the UI opened.\n': '',
    '- Added global API discovery, automatic UI retry, and a visible waiting status when HelperPayroll is detected.\n': '',
    '- Added optional HelperPayroll role selection to the Helper Profiles screen.\n': '',
    '- Added staged per-helper role editing with savegame persistence through the HelperPayroll public API.\n': '',
    '- Kept HelperPayroll optional; role controls are hidden when its API is unavailable.\n': '',
    '- Behoben: HelperPayroll-Rollensteuerung blieb bei später API-Bereitstellung ausgeblendet.\n': '',
    '- Optionale HelperPayroll-Lohnrollenauswahl zur Helferprofil-Oberfläche hinzugefügt.\n': '',
    '- Rollenänderungen pro Helfer werden vorgemerkt und über die öffentliche HelperPayroll-API im Spielstand gespeichert.\n': '',
    '- HelperPayroll bleibt optional; die Rollensteuerung wird ohne verfügbare API ausgeblendet.\n': '',
    '- Correction des commandes de rôle masquées lorsque l’API HelperPayroll était publiée après l’ouverture de l’interface.\n': '',
    "- Ajout de la sélection optionnelle du rôle HelperPayroll dans l'écran des profils d'aides.\n": '',
    "- Les changements de rôle par aide sont préparés puis enregistrés dans la sauvegarde via l'API publique HelperPayroll.\n": '',
    "- HelperPayroll reste optionnel ; les commandes de rôle sont masquées lorsque son API est indisponible.\n": '',
}
for old, new in replacements.items():
    s = s.replace(old, new)
write(path, s)

expected = {
    'scripts/gui/HP_AppearanceBindingsScreen.lua': 'f479c73be8ae5f9356f3fb0eebc031d0aa9d2448a4e89e0ee0505537a1b7a3d0',
    'gui/HP_AppearanceBindingsScreen.xml': 'ef7cd94170f9c5006da48a24d2cdcce6937476e9b497f3edc282f1417fa7a371',
    'gui/guiProfiles.xml': 'e34222abaf7bb180a053ef260b301575cd77115964bf5293d9d01fccdfdcdf6d',
    'l10n/l10n_en.xml': '04660482276312dc6fa95841585312f67d6f8ec604254ff101ec362c37c3c0dc',
    'l10n/l10n_de.xml': 'f511a5febbce9b4862a4c8bae2887b9a0a7eb466f2b2a6665fdbd816ec23340e',
    'l10n/l10n_fr.xml': '8cd85a95aace46cd0e8c95120390d7754398ab60b90d5de9e9d84254fe2871a0',
    'modDesc.xml': '2c595136a9c0587481ec23015b9bd965bf936d4a2b02e1236cfc1ff30c96a223',
}
for path, digest in expected.items():
    actual = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
    if actual != digest:
        raise RuntimeError(f'{path}: expected {digest}, got {actual}')

print('appearance-only binding UI patch verified')
