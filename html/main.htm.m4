MAIN_BEGIN
MAIN_PANEL_BEGIN

<script>
  function on_new() {
    div_show('form1')
  }
  function on_edit(id) {
  }
  function on_delete(id) {
  }
</script>

      <h3>Тут должна быть лента новостей</h3>
      <p>Написать: <img src="img/edit.png" class="pointer"
         onclick="div_show('form1')" alt="Добавить новое сообщение">

MAIN_PANEL_END

  <!-- Всплывающий диалог нового сообщения -->
  <div style="display:none;" id="form1" class="fullscreen">
  <div class="fullscreen shade"></div>
  <!-- div class="i_popup" -->
  <form action="#" class="popup" id="form1" method="post" name="form">
    <img class="close" src="img/x.png" onclick ="div_hide('form1')">
    <h2>Новое собщение</h2>
    <hr class="wide">
    <input id="title" name="title" placeholder="Заголовок" type="text">
    <textarea id="text" name="text" placeholder="Текст"></textarea>
    <p>Тип новости:</p>
    <select id="type" name="type">
      <option>1</option>
      <option>2</option>
      <option>3</option>
    </select>
    <a href="javascript:%20publish('form1')" class="submit_button">Опубликовать</a>
  </form>
  </div></div>

MAIN_END
