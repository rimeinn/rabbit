/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#Include RabbitConfigToolTip.ahk
#Include RabbitConfigValue.ahk
#Include RabbitEngineLists.ahk
#Include RabbitStringListItemDialog.ahk

#Include RabbitI18n.ahk

class RabbitEngineListsEditor {
    static MeasureHeight(owner, field) {
        local control, list_height
        control := owner.AddListBox("x0 y0 w100 r" . owner.GetListRows(field) . " Hidden", [])
        control.GetPos(, , , &list_height)
        return 190 + list_height * 2
    }

    __New(owner, field, y) {
        local card_height, card_width, footer_y, list_height, right_x, second_row_y
        this.owner := owner
        this.field := field
        this.width := owner.content_width - 24
        this.rows := owner.GetListRows(field)
        this.cards := Map()
        this.values := RabbitEngineLists.Validate(owner.draft_values[field.id])
        this.owner.draft_values[field.id] := RabbitConfigValue.Clone(this.values)

        this.label := owner.AddContentText("x12 y" . y . " w" . this.width . " h22 +0x200", field.label)
        y += 26
        card_width := Floor((this.width - 12) / 2)
        right_x := 12 + card_width + 12
        this.AddCard("processors", 12, y, card_width)
        this.cards["processors"].list.GetPos(, , , &list_height)
        card_height := 22 + list_height + 4 + 28
        this.AddCard("segmentors", right_x, y, card_width)
        second_row_y := y + card_height + 10
        this.AddCard("translators", 12, second_row_y, card_width)
        this.AddCard("filters", right_x, second_row_y, card_width)

        footer_y := second_row_y + card_height + 10
        this.reset_hint := owner.AddContentMutedText(
            "x12 y" . footer_y . " w" . (this.width - 132) . " h28 +0x200",
            ""
        )
        this.reset_button := owner.AddListButton(
            "x" . (12 + this.width - 110) . " y" . footer_y . " w110 h28 +0x2000",
            RabbitI18n.Text("engine_lists.restore_default"),
            (*) => this.RestoreDefault()
        )
        RabbitConfigToolTip.Apply(owner.ConfigId(), field.path, this.label, this.reset_hint, this.reset_button)
        this.bottom := footer_y + 36
        this.Refresh()
    }

    AddCard(name, x, y, width) {
        local button_gap := 4, button_width, buttons_y, card := { name: name }, list_height
        card.label := this.owner.AddContentText(
            "x" . x . " y" . y . " w" . width . " h22 +0x200",
            RabbitI18n.Text("engine_lists." . name)
        )
        card.list := this.owner.content_gui.AddListBox(
            "x" . x . " y" . (y + 22) . " w" . width . " r" . this.rows,
            []
        )
        this.owner.TrackScrollableContentControl(card.list)
        card.list.OnEvent("DoubleClick", (*) => this.EditItem(name))
        card.list.GetPos(, , , &list_height)
        buttons_y := y + 22 + list_height + 4
        button_width := Floor((width - button_gap * 3) / 4)
        card.add_button := this.owner.AddListButton(
            "x" . x . " y" . buttons_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.add"),
            (*) => this.AddItem(name)
        )
        card.delete_button := this.owner.AddListButton(
            "x" . (x + button_width + button_gap) . " y" . buttons_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.delete"),
            (*) => this.DeleteItem(name)
        )
        card.up_button := this.owner.AddListButton(
            "x" . (x + (button_width + button_gap) * 2) . " y" . buttons_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.move_up"),
            (*) => this.MoveItem(name, -1)
        )
        card.down_button := this.owner.AddListButton(
            "x" . (x + (button_width + button_gap) * 3) . " y" . buttons_y . " w" . button_width . " h28 +0x2000",
            RabbitI18n.Text("controls.move_down"),
            (*) => this.MoveItem(name, 1)
        )
        this.cards[name] := card
        RabbitConfigToolTip.Apply(
            this.owner.ConfigId(),
            RabbitEngineLists.ListPath(name),
            card.label,
            card.list,
            card.add_button,
            card.delete_button,
            card.up_button,
            card.down_button
        )
    }

    AddItem(name) {
        local item := RabbitStringListItemDialog(this.owner, "", false, this.owner.dark_mode_reader).ShowModal()
        if !item {
            return false
        }
        this.values[name].Push(item["value"])
        this.CommitChange(name, this.values[name].Length)
        return true
    }

    EditItem(name, row := 0) {
        local item
        if !row {
            row := this.cards[name].list.Value
        }
        if row < 1 || row > this.values[name].Length {
            return false
        }
        item := RabbitStringListItemDialog(
            this.owner,
            this.values[name][row],
            true,
            this.owner.dark_mode_reader
        ).ShowModal()
        if !item {
            return false
        }
        this.values[name][row] := item["value"]
        this.CommitChange(name, row)
        return true
    }

    DeleteItem(name) {
        local row := this.cards[name].list.Value
        if row < 1 || row > this.values[name].Length {
            return false
        }
        this.values[name].RemoveAt(row)
        this.CommitChange(name, Min(row, this.values[name].Length))
        return true
    }

    MoveItem(name, offset) {
        local item, row := this.cards[name].list.Value, target := row + offset
        if row < 1 || target < 1 || target > this.values[name].Length {
            return false
        }
        item := this.values[name].RemoveAt(row)
        this.values[name].InsertAt(target, item)
        this.CommitChange(name, target)
        return true
    }

    CommitChange(name, selected_row := 0) {
        this.owner.CancelEngineListsReset(this.field)
        this.owner.draft_values[this.field.id] := RabbitConfigValue.Clone(this.values)
        this.RefreshList(name, selected_row)
        this.RefreshResetState()
    }

    RestoreDefault() {
        return this.owner.RestoreEngineListsDefault(this.field)
    }

    Refresh() {
        local name
        for name in RabbitEngineLists.NAMES {
            this.RefreshList(name)
        }
        this.RefreshResetState()
    }

    RefreshList(name, selected_row := 0) {
        local item, list := this.cards[name].list
        list.Delete()
        for item in this.values[name] {
            list.Add([item])
        }
        if selected_row && selected_row <= this.values[name].Length {
            list.Choose(selected_row)
        }
    }

    RefreshResetState() {
        this.reset_hint.Value := this.owner.reset_fields.Has(this.field.id)
            ? RabbitI18n.Text("controls.restore_schema_default_pending") : ""
    }
}
