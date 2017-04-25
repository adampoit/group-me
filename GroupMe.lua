-------------------------------------------------------------------------------
-- Group Me
-------------------------------------------------------------------------------
-- Copyright (C) 2017 Adam Poit
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
-------------------------------------------------------------------------------

function GroupMe_OnLoad()
  GroupMe_Frame.Active = false;
  GroupMe_Frame.SearchRate = 10;
  GroupMe_Frame.TimeSinceLastSearch = 0;
  GroupMe_Frame.ApplicationRate = 1;
  GroupMe_Frame.TimeSinceLastApplication = 0;
  GroupMe_Frame.PreviousLeaderNames = {};
  GroupMe_Frame.Queue = {};

  GroupMe_Frame:SetScript("OnUpdate", GroupMe_OnUpdate);
  GroupMe_Frame:RegisterEvent("LFG_LIST_JOINED_GROUP");

  print("Group Me v0.1 Loaded");
end

function GroupMe_OnEvent(self, event, ...)
  if (event == "LFG_LIST_JOINED_GROUP") then
    GroupMe_Off();
  end
end

function GroupMe_On()
  if not LFGListFrame.SearchPanel.categoryID then
    print("Open up the LFG panel first.");
    return;
  end

  GroupMe_RoleDialog_Show(GroupMe_RoleDialog);
end

function GroupMe_Off()
  print("GroupMe disabled.");
  GroupMe_Frame.Active = false;
end

function GroupMe_OnUpdate(this, arg)
  if not GroupMe_Frame.Active then return end

  GroupMe_Frame.TimeSinceLastSearch = GroupMe_Frame.TimeSinceLastSearch + arg;
  if GroupMe_Frame.TimeSinceLastSearch > GroupMe_Frame.SearchRate then
    LFGListSearchPanel_DoSearch(LFGListFrame.SearchPanel);
    GroupMe_Frame.TimeSinceLastSearch = 0;
  end

  GroupMe_Frame.TimeSinceLastApplication = GroupMe_Frame.TimeSinceLastApplication + arg;
  if GroupMe_Frame.TimeSinceLastApplication > GroupMe_Frame.ApplicationRate then
    for k,v in pairs(GroupMe_Frame.Queue) do
      local id, activity, name, _, _, _, _, _, _, _, _, isDelisted, leaderName = C_LFGList.GetSearchResultInfo(k);
      local messageApply = LFGListUtil_GetActiveQueueMessage(true);
      local numApplications, numActiveApplications = C_LFGList.GetNumApplications();

      if v and not isDelisted and leaderName and not GroupMe_Frame.PreviousLeaderNames[leaderName] and not messageApply and not
        (IsInGroup(LE_PARTY_CATEGORY_HOME) and C_LFGList.IsCurrentlyApplying()) and numActiveApplications < MAX_LFG_LIST_APPLICATIONS then
        GroupMe_Frame.Queue[k] = false;

        print("Signed up to ", name);
        GroupMe_Frame.PreviousLeaderNames[leaderName] = true;
        local _, tank, healer, dps = GetLFGRoles();
        C_LFGList.ApplyToGroup(id, "", tank, healer, dps);

        GroupMe_Frame.TimeSinceLastApplication = 0;
        return;
      end
    end
  end
end

function GroupMe_OnLFGListSearchEntryUpdate(self)
  if not GroupMe_Frame.Active then return end

  local id = C_LFGList.GetSearchResultInfo(self.resultID);
  GroupMe_Frame.Queue[id] = true;
end

function GroupMe_RoleDialog_OnLoad(self)
  self:RegisterEvent("LFG_ROLE_UPDATE");
  self.hideOnEscape = true;
end

function GroupMe_RoleDialog_OnEvent(self, event)
  if ( event == "LFG_ROLE_UPDATE" ) then
    GroupMe_RoleDialog_UpdateRoles(self);
  end
end

function GroupMe_RoleDialog_Show(self)
  GroupMe_RoleDialog_UpdateRoles(self);
  StaticPopupSpecial_Show(self);
end

function GroupMe_RoleDialog_UpdateRoles(self)
  local availTank, availHealer, availDPS = C_LFGList.GetAvailableRoles();

  local avail1, avail2, avail3;
  if ( availTank ) then
    avail1 = self.TankButton;
  end
  if ( availHealer ) then
    if ( avail1 ) then
      avail2 = self.HealerButton;
    else
      avail1 = self.HealerButton;
    end
  end
  if ( availDPS ) then
    if ( avail2 ) then
      avail3 = self.DamagerButton;
    elseif ( avail1 ) then
      avail2 = self.DamagerButton;
    else
      avail1 = self.DamagerButton;
    end
  end

  self.TankButton:SetShown(availTank);
  self.HealerButton:SetShown(availHealer);
  self.DamagerButton:SetShown(availDPS);

  if ( avail3 ) then
    avail1:ClearAllPoints();
    avail1:SetPoint("TOPRIGHT", self, "TOP", -53, -35);
    avail2:ClearAllPoints();
    avail2:SetPoint("TOP", self, "TOP", 0, -35);
    avail3:ClearAllPoints();
    avail3:SetPoint("TOPLEFT", self, "TOP", 53, -35);
  elseif ( avail2 ) then
    avail1:ClearAllPoints();
    avail1:SetPoint("TOPRIGHT", self, "TOP", -5, -35);
    avail2:ClearAllPoints();
    avail2:SetPoint("TOPLEFT", self, "TOP", 5, -35);
  elseif ( avail1 ) then
    avail1:ClearAllPoints();
    avail1:SetPoint("TOP", self, "TOP", 0, -35);
  end

  local _, tank, healer, dps = GetLFGRoles();
  self.TankButton.CheckButton:SetChecked(tank);
  self.HealerButton.CheckButton:SetChecked(healer);
  self.DamagerButton.CheckButton:SetChecked(dps);

  GroupMe_RoleDialog_UpdateValidState(self);
end

function GroupMe_RoleDialog_UpdateValidState(self)
  if (( self.TankButton:IsShown() and self.TankButton.CheckButton:GetChecked())
    or (self.HealerButton:IsShown() and self.HealerButton.CheckButton:GetChecked())
    or (self.DamagerButton:IsShown() and self.DamagerButton.CheckButton:GetChecked())) then
    self.SignUpButton:Enable();
    self.SignUpButton.errorText = nil;
  else
    self.SignUpButton:Disable();
    self.SignUpButton.errorText = LFG_LIST_MUST_SELECT_ROLE;
  end
end

function GroupMe_RoleDialog_OnClick(self)
  if (self:GetChecked()) then
    PlaySound("igMainMenuOptionCheckBoxOn");
  else
    PlaySound("igMainMenuOptionCheckBoxOff");
  end

  local dialog = self:GetParent():GetParent();
  local leader, tank, healer, dps = GetLFGRoles();
  SetLFGRoles(leader, dialog.TankButton.CheckButton:GetChecked(), dialog.HealerButton.CheckButton:GetChecked(), dialog.DamagerButton.CheckButton:GetChecked());
end

SlashCmdList["GROUPME"] = function(s)
  if GroupMe_Frame.Active then GroupMe_Off() else GroupMe_On() end
end

SLASH_GROUPME1 = "/gm";
SLASH_GROUPME2 = "/groupme";

hooksecurefunc("LFGListSearchEntry_Update", GroupMe_OnLFGListSearchEntryUpdate);
