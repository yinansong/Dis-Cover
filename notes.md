### Iterating through the array of manholes
  <ul>
  <% @manholes.each do |manhole_entry| %>
    <li>
      <ul>
      <% manhole_entry %>
        <img src="<%= manhole_entry["img"] %>" style="width:200px;">
        <li><%= manhole_entry["city"] %>, <%= manhole_entry["province_or_state"] %>, <%= manhole_entry["country"] %></li>
        <li><%= manhole_entry["year"] %></li>
        <li><%= manhole_entry["color"] %></li>3
        <li><%= manhole_entry["shape"] %></li>
        <li><%= manhole_entry["note"] %></li>
        <li><%= manhole_entry["tags"] %></li>
      </ul>
    </li>
  <% end %>
  </ul>

### Draggable Issue
- found this ticket online: http://bugs.jqueryui.com/ticket/3446
-

### Just in case you want the old meta-box back
    <div id="meta_box<%= index %>" class="meta_box">
      <p class="meta_text" id="meta_location"><%= manhole_entry["city"] %>, <%= manhole_entry["province_or_state"] %>, <%= manhole_entry["country"] %></p><br>
      <p class="meta_text" id="meta_year"><%= manhole_entry["year"] %></p><br>
      <p class="meta_text" id="meta_info"><%= manhole_entry["note"] %></p>
    </div>
