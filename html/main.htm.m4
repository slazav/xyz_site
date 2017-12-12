MAIN_BEGIN
MAIN_PANEL_BEGIN

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
    <input id="name" name="title" placeholder="Заголовок" type="text">
    <textarea id="msg" name="text" placeholder="Текст"></textarea>
    <a href="javascript:%20publish('form1')" class="submit_button">Опубликовать</a>
  </form>
  </div></div>

MAIN_END
