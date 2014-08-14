# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2008 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
#**************************************************************************

# File:	firewall_stage1_proposal.ycp
# Summary:	Configuration of fw in 1st stage
# Author:	Bubli <kmachalkova@suse.cz>
#
require "yast"

module Yast
  class FirewallStage1ProposalClient < Client
    PROPOSAL_ID = "fw_1ststage"

    LINK_ENABLE_FIREWALL = "firewall--enable_firewall_in_proposal"
    LINK_DISABLE_FIREWALL = "firewall--disable_firewall_in_proposal"
    LINK_OPEN_SSH_PORT = "firewall--enable_ssh_port_in_proposal"
    LINK_BLOCK_SSH_PORT = "firewall--disable_ssh_port_in_proposal"
    LINK_ENABLE_SSHD = "firewall--enable_sshd_in_proposal"
    LINK_DISABLE_SSHD = "firewall--disable_sshd_in_proposal"
    LINK_ENABLE_VNC = "firewall--enable_vnc_in_proposal"
    LINK_DISABLE_VNC = "firewall--disable_vnc_in_proposal"
    LINK_FIREWALL_DIALOG = "firewall_stage1"

    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Label"
      Yast.import "Linuxrc"
      Yast.import "PackagesProposal"
      Yast.import "ProductControl"
      Yast.import "Progress"
      Yast.import "SuSEFirewall"
      Yast.import "SuSEFirewall4Network"
      Yast.import "SuSEFirewallProposal"
      Yast.import "Wizard"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      if @func == "MakeProposal"
        # Don't override users settings
        SuSEFirewall4Network.prepare_proposal unless SuSEFirewallProposal.GetChangedByUser

        @ret = {
          "preformatted_proposal" => preformatted_proposal,
          "warning_level"         => :warning,
          "links"                 => [
            LINK_ENABLE_FIREWALL,
            LINK_DISABLE_FIREWALL,
            LINK_OPEN_SSH_PORT,
            LINK_BLOCK_SSH_PORT,
            LINK_ENABLE_SSHD,
            LINK_DISABLE_SSHD,
            LINK_ENABLE_VNC,
            LINK_DISABLE_VNC
          ]
        }

        adjust_configuration
      elsif @func == "AskUser"
        @chosen_link = Ops.get(@param, "chosen_id")
        @result = :next
        Builtins.y2milestone("User clicked %1", @chosen_link)

        case @chosen_link
        when LINK_ENABLE_FIREWALL
          Builtins.y2milestone("Enabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(true)
          PackagesProposal.AddResolvables(PROPOSAL_ID, :package, [SuSEfirewall2.FIREWALL_PACKAGE])
        when LINK_DISABLE_FIREWALL
          Builtins.y2milestone("Disabling FW")
          SuSEFirewall4Network.SetEnabled1stStage(false)
          PackagesProposal.RemoveResolvables(PROPOSAL_ID, :package, [SuSEfirewall2.FIREWALL_PACKAGE])
        when LINK_OPEN_SSH_PORT
          Builtins.y2milestone("Opening SSH port")
          SuSEFirewall4Network.SetSshEnabled1stStage(true)
        when LINK_BLOCK_SSH_PORT
          Builtins.y2milestone("Blocking SSH port")
          SuSEFirewall4Network.SetSshEnabled1stStage(false)
        when LINK_ENABLE_SSHD
          Builtins.y2milestone("Enabling SSHD")
          PackagesProposal.AddResolvables(PROPOSAL_ID, :package, ["openssh"])
          SuSEFirewall4Network.SetSshdEnabled(true)
        when LINK_DISABLE_SSHD
          Builtins.y2milestone("Disabling SSHD")
          SuSEFirewall4Network.SetSshdEnabled(false)
          PackagesProposal.RemoveResolvables(PROPOSAL_ID, :package, ["openssh"])
        when LINK_ENABLE_VNC
          Builtins.y2milestone("Enabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(true)
        when LINK_DISABLE_VNC
          Builtins.y2milestone("Disabling VNC")
          SuSEFirewall4Network.SetVncEnabled1stStage(false)
        when LINK_FIREWALL_DIALOG
          @result = FirewallDialogSimple()
        else
          raise "INTERNAL ERROR: unknown action '#{@chosen_link}' for proposal client"
        end

        SuSEFirewallProposal.SetChangedByUser(true)

        @ret = { "workflow_sequence" => @result }

        adjust_configuration
      elsif @func == "Description"
        @ret = {
          # Proposal title
          "rich_text_title" => _("Firewall and SSH"),
          # Menu entry label
          "menu_title"      => _("&Firewall and SSH"),
          "id"              => LINK_FIREWALL_DIALOG
        }
      elsif @func == "Write"
        @ret = { "success" => true }
      end

      deep_copy(@ret)
    end

    def FirewallDialogSimple
      title = _("Basic Firewall and SSH Configuration")

      vnc_support = Left(
        CheckBox(
          Id("open_vnc_port"),
          # TRANSLATORS: check-box label
          _("Open &VNC Ports"),
          SuSEFirewall4Network.EnabledVnc1stStage
        )
      )

      contents = VBox(
        Frame(
          # frame label
          _("Firewall and SSH service"),
          HSquash(
            MarginBox(
              0.5,
              0.5,
              VBox(
                Left(
                  CheckBox(
                    Id("enable_fw"),
                    Opt(:notify),
                    # TRANSLATORS: check-box label
                    _("Enable Firewall"),
                    SuSEFirewall4Network.Enabled1stStage
                  )
                ),
                Left(
                  CheckBox(
                    Id("open_ssh_port"),
                    # TRANSLATORS: check-box label
                    _("Open SSH Port"),
                    SuSEFirewall4Network.EnabledSsh1stStage
                  )
                ),
                Left(
                  CheckBox(
                    Id("enable_sshd"),
                    # TRANSLATORS: check-box label
                    _("Enable SSH Service"),
                    SuSEFirewall4Network.EnabledSshd
                  )
                ),

                Linuxrc.vnc ? vnc_support : Empty()
              )
            )
          )
        )
      )

      help = _(
        "<p><b><big>Firewall and SSH</big></b><br>\n" +
          "Firewall is a defensive mechanism that protects your computer from network attacks.\n" +
          "SSH is a service that allows logging into this computer remotely via dedicated\n" +
          "SSH client</p>"
      ) +
        _(
          "<p>Here you can choose whether the firewall will be enabled or disabled after\nthe installation. It is recommended to keep it enabled.</p>"
        ) +
        _(
          "<p>With enabled firewall, you can decide whether to open firewall port for SSH\n" +
            "service and allow remote SSH logins. Independently you can also enable SSH service (i.e. it\n" +
            "will be started on computer boot).</p>"
        ) +
        (Linuxrc.vnc ?
          # TRANSLATORS: help text
          _(
            "<p>You can also open VNC ports in firewall. It will not enable\n" +
              "the remote administration service on a running system but it is\n" +
              "started by the installer automatically if needed.</p>"
          ) :
          "")

      Wizard.CreateDialog
      Wizard.SetTitleIcon("yast-firewall")

      Wizard.SetContentsButtons(
        title,
        contents,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:cancel, Label.CancelButton)
      Wizard.HideBackButton

      UI.ChangeWidget(
        Id("open_ssh_port"),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )
      UI.ChangeWidget(
        Id("open_vnc_port"),
        :Enabled,
        SuSEFirewall4Network.Enabled1stStage
      )

      dialog_ret = nil

      while true
        dialog_ret = UI.UserInput
        enable_firewall = Convert.to_boolean(
          UI.QueryWidget(Id("enable_fw"), :Value)
        )

        if dialog_ret == "enable_fw"
          UI.ChangeWidget(Id("open_ssh_port"), :Enabled, enable_firewall)
          UI.ChangeWidget(Id("open_vnc_port"), :Enabled, enable_firewall)
          next
        elsif dialog_ret == :next || dialog_ret == :ok
          open_ssh_port = Convert.to_boolean(
            UI.QueryWidget(Id("open_ssh_port"), :Value)
          )
          open_vnc_port = Convert.to_boolean(
            UI.QueryWidget(Id("open_vnc_port"), :Value)
          )

          SuSEFirewall4Network.SetEnabled1stStage(enable_firewall)

          if enable_firewall
            SuSEFirewall4Network.SetSshEnabled1stStage(open_ssh_port)
            SuSEFirewall4Network.SetVncEnabled1stStage(open_vnc_port)
          end

          SuSEFirewall4Network.SetSshdEnabled(
            UI::QueryWidget(Id("enable_sshd"), :Value)
          )
        end

        # anything but enabling the firewall closes this dialog
        # (VNC and SSH checkboxes do nothing)
        break
      end

      Wizard.CloseDialog
      Convert.to_symbol(dialog_ret)
    end

  private

    def preformatted_proposal

      firewall_proposal = SuSEFirewall4Network.Enabled1stStage ?
          _(
            "Firewall will be enabled (<a href=\"%s\">disable</a>)"
          ) % LINK_DISABLE_FIREWALL
        :
          _(
            "Firewall will be disabled (<a href=\"%s\">enable</a>)"
          ) % LINK_ENABLE_FIREWALL

      sshd_proposal = SuSEFirewall4Network.EnabledSshd ?
          _(
            "SSH service will be enabled (<a href=\"%s\">disable</a>)"
          ) % LINK_DISABLE_SSHD
        :
          _(
            "SSH service will be disabled (<a href=\"%s\">enable</a>)"
          ) % LINK_ENABLE_SSHD

      vnc_fw_proposal = nil
      ssh_fw_proposal = nil
      # It only makes sense to show the blocked ports if firewall is
      # enabled (bnc#886554)
      if SuSEFirewall4Network.Enabled1stStage
        # Display vnc port only if installing over VNC
        if Linuxrc.vnc
          vnc_fw_proposal = SuSEFirewall4Network.EnabledVnc1stStage ?
            _("VNC ports will be open (<a href=\"%s\">close</a>)") %
              LINK_DISABLE_VNC
            : _("VNC ports will be blocked (<a href=\"%s\">open</a>)") %
              LINK_ENABLE_VNC
        end

        ssh_fw_proposal = SuSEFirewall4Network.EnabledSsh1stStage ?
            _(
              "SSH port will be open (<a href=\"%s\">block</a>)"
            ) % LINK_BLOCK_SSH_PORT
          :
            _(
              "SSH port will be blocked (<a href=\"%s\">open</a>)"
            ) % LINK_OPEN_SSH_PORT
      end

      # Filter proposals with content and sort them
      proposals = [firewall_proposal, ssh_fw_proposal, sshd_proposal, vnc_fw_proposal].compact
      "<ul>\n" + proposals.map {|prop| "<li>#{prop}</li>\n" }.join + "</ul>\n"
    end

    # Reads and adjust the configuration for SuSEfirewall2 according to the current proposal.
    # bnc#887406: This needs to be done before user exports any configuration
    # to AutoYast profile.
    def adjust_configuration
      enable_fw = SuSEFirewall4Network.Enabled1stStage
      open_ssh_port = SuSEFirewall4Network.EnabledSsh1stStage
      open_vnc_port = SuSEFirewall4Network.EnabledVnc1stStage

      log.info "After installation, firewall will be #{enable_fw ? 'enabled':'disabled'}, " <<
        "SSH port will be #{open_ssh_port ? 'open':'closed'} " <<
        "VNC port will be #{open_vnc_port ? 'open':'closed'}"

      # Read the configuration from sysconfig
      # bnc#887406: The file is in inst-sys
      previous_state = Progress.set(false)
      SuSEFirewall.Read
      Progress.set(previous_state)

      SuSEFirewall.SetEnableService(enable_fw)
      SuSEFirewall.SetStartService(enable_fw)

      # only if we have openssh package - proposal takes care
      # it gets installed if the user wants to open ssh port
      if open_ssh_port
        SuSEFirewall.SetServicesForZones(
          ["service:sshd"],
          SuSEFirewall.GetKnownFirewallZones,
          true
        )
      end

      if open_vnc_port
        SuSEFirewall.SetServicesForZones(
          ["service:xorg-x11-Xvnc"],
          SuSEFirewall.GetKnownFirewallZones,
          true
        )
      end

      # Writing the configuration including adjusting services
      # is done in firewall_stage1_finish
    end

  end unless defined? FirewallStage1ProposalClient
end

Yast::FirewallStage1ProposalClient.new.main
