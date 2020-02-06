import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default {
  name: "discourse-group-timezones",

  initialize() {
    withPluginApi("0.8.7", api => {
      let _glued = [];

      function cleanUp() {
        _glued.forEach(g => g.cleanUp());
        _glued = [];
      }

      function _attachWidget(api, container, options) {
        const glue = new WidgetGlue(
          "discourse-group-timezones",
          getRegister(api),
          options
        );
        glue.appendTo(container);
        _glued.push(glue);
      }

      function _loadGroupMembers(group) {
        return ajax(`/groups/${group}/members.json?limit=50`, {
          type: "GET",
          cache: false
        })
          .then(groupResult => {
            if (groupResult && groupResult.members) {
              return groupResult.members;
            }
          })
          .catch(popupAjaxError);
      }

      function _attachGroupTimezones($elem, id = 1) {
        const $groupTimezones = $(".group-timezones", $elem);

        if (!$groupTimezones.length) {
          return;
        }

        $groupTimezones.each((idx, groupTimezone) => {
          const group = groupTimezone.getAttribute("data-group");
          if (!group) {
            // throw "[group] attribute is necessary when using group-timezones.";
          }

          groupTimezone.innerHTML = "<div class='spinner'></div>";

          _loadGroupMembers(group).then(members => {
            _attachWidget(api, groupTimezone, {
              id: `${id}-${idx}`,
              members,
              group,
              usersOnHoliday:
                api.container.lookup("site:main").users_on_holiday || [],
              size: groupTimezone.getAttribute("data-size") || "medium"
            });
          });
        });
      }

      function _attachPostWithGroupTimezones($elem, helper) {
        if (helper) {
          const post = helper.getModel();
          api.preventCloak(post.id);
          _attachGroupTimezones($elem, post.id);
        }
      }

      api.decorateCooked(_attachPostWithGroupTimezones, {
        id: "discourse-group-timezones"
      });

      api.onPageChange(url => {
        const match = url.match(/\/g\/(\w+)/);
        if (match && match.length && match[1]) {
          const $elem = $(".group-bio");
          if ($elem.length) {
            _attachGroupTimezones($elem);
          }
        }
      });

      api.cleanupStream(cleanUp);
    });
  }
};
