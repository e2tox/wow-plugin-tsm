-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local Vendoring = TSM.MainUI.Operations:NewPackage("Vendoring")
local L = TSM.Include("Locale").GetTable()
local Money = TSM.Include("Util.Money")
local private = {
	currentOperationName = nil,
}

local RESTOCK_SOURCES = { bank = BANK, guild = GUILD, alts = L["Alts"], alts_ah = L["Alts AH"], ah = L["AH"], mail = L["Mail"] }
local RESTOCK_SOURCES_ORDER = { "bank", "guild", "alts", "alts_ah", "ah", "mail" }

-- ============================================================================
-- Module Functions
-- ============================================================================

function Vendoring.OnInitialize()
	TSM.MainUI.Operations.RegisterModule("Vendoring", private.GetVendoringOperationSettings)
end



-- ============================================================================
-- Vendoring Operation Settings UI
-- ============================================================================

function private.GetVendoringOperationSettings(operationName)
	TSM.UI.AnalyticsRecordPathChange("main", "operations", "vendoring")
	private.currentOperationName = operationName

	local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
	return TSMAPI_FOUR.UI.NewElement("Frame", "content")
		:SetLayout("VERTICAL")
		:AddChild(TSMAPI_FOUR.UI.NewElement("Texture", "line")
			:SetStyle("color", "#9d9d9d")
			:SetStyle("height", 2)
			:SetStyle("margin.top", 24)
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("ScrollFrame", "settings")
			:SetStyle("background", "#1e1e1e")
			:SetStyle("padding.left", 16)
			:SetStyle("padding.right", 16)
			:SetStyle("padding.top", -8)
			:AddChild(TSM.MainUI.Operations.CreateHeadingLine("buyOptionsHeading", L["Buy Options"]))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableBuy", L["Enable buying?"])
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "enableBuyingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin.right", -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn"))
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "toggle")
						:SetSettingInfo(operation, "enableBuy")
						:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "enableBuy"))
						:SetScript("OnValueChanged", private.EnableBuyingToggleOnValueChanged)
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockQty", L["Restock quantity:"], not operation.enableBuy)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin.right", -112)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "restockQtyInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin.right", 16)
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "restockQty")
					:SetMaxNumber(5000)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "restockQty") or not operation.enableBuy)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "restockQtyMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", (TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "restockQty") or not operation.enableBuy) and "#424242" or "#e2e2e2")
					:SetText(format(L["(max %d)"], 5000))
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockSources", L["Sources to include for restock:"], not operation.enableBuy)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Dropdown", "restockSourcesDropdown")
					:SetMultiselect(true)
					:SetDictionaryItems(RESTOCK_SOURCES, operation.restockSources, RESTOCK_SOURCES_ORDER)
					:SetSettingInfo(operation, "restockSources")
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "restockSources") or not operation.enableBuy)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateHeadingLine("sellOptionsHeading", L["Sell Options"]))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableSell", L["Enable selling?"])
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "enableSellingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin.right", -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn"))
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "toggle")
						:SetSettingInfo(operation, "enableSell")
						:SetScript("OnValueChanged", private.EnableSellingToggleOnValueChanged)
						:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "enableSell"))
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("keepQty", L["Keep quantity:"], not operation.enableSell)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin.right", -112)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "keepQtyInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin.right", 16)
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "keepQty")
					:SetMaxNumber(5000)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "enableSell") or not operation.enableSell)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "keepQtyMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", (TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "keepQty") or not operation.enableSell) and "#424242" or "#e2e2e2")
					:SetText(L["(max 5000)"])
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("sellAfterExpired", L["Minimum expires:"], not operation.enableSell)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin.right", -112)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "sellAfterExpiredInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin.right", 16)
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "sellAfterExpired")
					:SetMaxNumber(5000)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "sellAfterExpired") or not operation.enableSell)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "sellAfterExpiredMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", (TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "sellAfterExpired") or not operation.enableSell) and "#424242" or "#e2e2e2")
					:SetText(L["(max 5000)"])
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsMarketValue", L["Market Value"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "marketValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 26)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "marketValueInput")
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 26)
					:SetSettingInfo(operation, "vsMarketValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "vsMarketValue") or not operation.enableSell)
					:SetText(Money.ToString(Money.FromString(operation.vsMarketValue)) or Money.ToString(operation.vsMarketValue) or operation.vsMarketValue)
					:SetScript("OnEnterPressed", private.MarketValueOnEnterPressed)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsMaxMarketValue", L["Maximum Market Value (Enter '0c' to disable)"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsMaxMarketValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 26)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsMaxMarketValueInput")
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 26)
					:SetSettingInfo(operation, "vsMaxMarketValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "vsMaxMarketValue") or not operation.enableSell)
					:SetText(Money.ToString(Money.FromString(operation.vsMaxMarketValue)) or Money.ToString(operation.vsMaxMarketValue) or operation.vsMaxMarketValue)
					:SetScript("OnEnterPressed", private.MaxMarketValueOnEnterPressed)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsDestroyValue", L["Destroy Value"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsDestroyValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 26)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsDestroyValueInput")
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 26)
					:SetSettingInfo(operation, "vsDestroyValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "vsDestroyValue") or not operation.enableSell)
					:SetText(Money.ToString(Money.FromString(operation.vsDestroyValue)) or Money.ToString(operation.vsDestroyValue) or operation.vsDestroyValue)
					:SetScript("OnEnterPressed", private.DestroyValueOnEnterPressed)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsMaxDestroyValue", L["Maximum Destroy Value (Enter '0c' to disable)"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsMaxDestroyValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 26)
				:SetStyle("margin.bottom", 16)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsMaxDestroyValueInput")
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 26)
					:SetDisabled(not operation.enableSell)
					:SetSettingInfo(operation, "vsMaxDestroyValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "vsMaxDestroyValue") or not operation.enableSell)
					:SetText(Money.ToString(Money.FromString(operation.vsMaxDestroyValue)) or Money.ToString(operation.vsMaxDestroyValue) or operation.vsMaxDestroyValue)
					:SetScript("OnEnterPressed", private.MaxDestroyValueOnEnterPressed)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("sellSoulbound", L["Sell soulbound items?"], not operation.enableSell)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "sellSoulboundSettingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin.right", -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn"))
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "sellSoulbound")
						:SetSettingInfo(operation, "sellSoulbound")
						:SetDisabled(TSM.Operations.HasRelationship("Vendoring", private.currentOperationName, "sellSoulbound") or not operation.enableSell)
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Vendoring", private.currentOperationName))
		)
end




-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.EnableBuyingToggleOnValueChanged(toggle, value)
	local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
	local settingsFrame = toggle:GetParentElement():GetParentElement():GetParentElement()
	settingsFrame:GetElement("restockQty.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("restockQty.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("restockQty.restockQtyInput")
		:SetDisabled(not value)
		:SetText(operation.restockQty or "")
	settingsFrame:GetElement("restockSources.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("restockSources.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("restockSources.restockSourcesDropdown")
		:SetDisabled(not value)
	settingsFrame:Draw()
end

function private.EnableSellingToggleOnValueChanged(toggle, value)
	local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
	local settingsFrame = toggle:GetParentElement():GetParentElement():GetParentElement()
	settingsFrame:GetElement("keepQty.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("keepQty.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("keepQty.keepQtyInput")
		:SetDisabled(not value)
		:SetText(operation.keepQty or "")
	settingsFrame:GetElement("keepQty.keepQtyMaxLabel")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("sellAfterExpired.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("sellAfterExpired.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("sellAfterExpired.sellAfterExpiredInput")
		:SetDisabled(not value)
		:SetText(operation.sellAfterExpired or "")
	settingsFrame:GetElement("sellAfterExpired.sellAfterExpiredMaxLabel")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsMarketValue.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsMarketValue.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("marketValueFrame.marketValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsMaxMarketValue.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsMaxMarketValue.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsMaxMarketValueFrame.vsMaxMarketValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsDestroyValue.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsDestroyValue.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsDestroyValueFrame.vsDestroyValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsMaxDestroyValue.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsMaxDestroyValue.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsMaxDestroyValueFrame.vsMaxDestroyValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("sellSoulbound.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("sellSoulbound.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("sellSoulbound.sellSoulboundSettingFrame.sellSoulbound")
		:SetDisabled(not value)

	settingsFrame:Draw()
end

function private.MarketValueOnEnterPressed(input)
	local text = input:GetText()
	if not TSM.MainUI.Operations.CheckCustomPrice(text) then
		local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
		input:SetText(Money.ToString(Money.FromString(operation.vsMarketValue)) or Money.ToString(operation.vsMarketValue) or operation.vsMarketValue)
			:Draw()
	else
		input:SetText(Money.ToString(Money.FromString(text)) or Money.ToString(text) or text)
			:Draw()
	end
end

function private.MaxMarketValueOnEnterPressed(input)
	local text = input:GetText()
	if not TSM.MainUI.Operations.CheckCustomPrice(text) then
		local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
		input:SetText(Money.ToString(Money.FromString(operation.vsMaxMarketValue)) or Money.ToString(operation.vsMaxMarketValue) or operation.vsMaxMarketValue)
			:Draw()
	else
		input:SetText(Money.ToString(Money.FromString(text)) or Money.ToString(text) or text)
			:Draw()
	end
end

function private.DestroyValueOnEnterPressed(input)
	local text = input:GetText()
	if not TSM.MainUI.Operations.CheckCustomPrice(text) then
		local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
		input:SetText(Money.ToString(Money.FromString(operation.vsDestroyValue)) or Money.ToString(operation.vsDestroyValue) or operation.vsDestroyValue)
			:Draw()
	else
		input:SetText(Money.ToString(Money.FromString(text)) or Money.ToString(text) or text)
			:Draw()
	end
end

function private.MaxDestroyValueOnEnterPressed(input)
	local text = input:GetText()
	if not TSM.MainUI.Operations.CheckCustomPrice(text) then
		local operation = TSM.Operations.GetSettings("Vendoring", private.currentOperationName)
		input:SetText(Money.ToString(Money.FromString(operation.vsMaxDestroyValue)) or Money.ToString(operation.vsMaxDestroyValue) or operation.vsMaxDestroyValue)
			:Draw()
	else
		input:SetText(Money.ToString(Money.FromString(text)) or Money.ToString(text) or text)
			:Draw()
	end
end
