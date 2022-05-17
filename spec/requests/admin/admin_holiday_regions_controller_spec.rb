# frozen_string_literal: true

require "rails_helper"

module Admin::DiscourseCalendar
  describe AdminHolidayRegionsController do
    fab!(:admin) { Fabricate(:user, admin: true) }
    fab!(:member) { Fabricate(:user) }

    before do
      SiteSetting.calendar_enabled = calendar_enabled
    end

    describe "#index" do
      context "when the calendar plugin is enabled" do
        let(:calendar_enabled) { true }

        it "returns a list of holiday regions for an admin" do
          sign_in(admin)
          get "/admin/discourse-calendar/holiday-regions.json"

          expect(response.parsed_body["holiday_regions"].count).to eq(262)
          expect(response.parsed_body["holiday_regions"]).to eq(
            %w(
              ar at au au_nsw au_vic au_qld au_nt au_act au_sa au_wa au_tas
              au_tas_south au_qld_cairns au_qld_brisbane au_tas_north
              au_vic_melbourne be_fr be_nl br br_spcapital br_sp bg_en bg_bg
              ca ca_qc ca_ab ca_sk ca_on ca_bc ca_nb ca_mb ca_ns ca_pe ca_nl
              ca_nt ca_nu ca_yt us ch_zh ch_be ch_lu ch_ur ch_sz ch_ow ch_nw
              ch_gl ch_zg ch_fr ch_so ch_bs ch_bl ch_sh ch_ar ch_ai ch_sg ch_gr
              ch_ag ch_tg ch_ti ch_vd ch_ne ch_ge ch_ju ch_vs ch cl co cr cz dk
              de de_bw de_by de_he de_nw de_rp de_sl de_sn_sorbian de_th_cath
              de_sn de_st de_be de_by_cath de_by_augsburg de_bb de_mv de_th
              de_hb de_hh de_ni de_sh ecbtarget ee el es_pv es_na es_an es_ib
              es_cm es_mu es_m es_ar es_cl es_cn es_lo es_ga es_ce es_o es_ex es
              es_ct es_v es_vc federalreserve federalreservebanks fedex fi fr_a
              fr_m fr gb gb_eng gb_wls gb_eaw gb_nir je gb_jsy gg gb_gsy gb_sct
              gb_con im gb_iom ge hr hk hu ie in is it it_ve it_tv it_vr it_pd
              it_fi it_ge it_to it_rm it_vi it_bl it_ro kr kz li lt lv ma mt_mt
              mt_en mx mx_pue nerc nl lu no nyse nz nz_sl nz_we nz_ak nz_nl
              nz_ne nz_ot nz_ta nz_sc nz_hb nz_mb nz_ca nz_ch nz_wl pe ph pl pt
              pt_li pt_po ro rs_cyrl rs_la ru se sa tn tr ua us_fl us_la us_ct
              us_de us_gu us_hi us_in us_ky us_nj us_nc us_nd us_pr us_tn us_ms
              us_id us_ar us_tx us_dc us_md us_va us_vt us_ak us_ca us_me us_ma
              us_al us_ga us_ne us_mo us_sc us_wv us_vi us_ut us_ri us_az us_co
              us_il us_mt us_nm us_ny us_oh us_pa us_mi us_mn us_nv us_or us_sd
              us_wa us_wi us_wy us_ia us_ks us_nh us_ok unitednations ups za ve
              sk si jp vi sg my th ng
            )
          )
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions.json"

          expect(response.status).to eq(404)
        end
      end

      context "when the calendar plugin is not enabled" do
        let(:calendar_enabled) { false }

        it "returns a 404 for an admin" do
          sign_in(admin)
          get "/admin/discourse-calendar/holiday-regions.json"

          expect(response.status).to eq(404)
        end

        it "returns a 404 for a member" do
          sign_in(member)
          get "/admin/discourse-calendar/holiday-regions.json"

          expect(response.status).to eq(404)
        end
      end
    end
  end
end
