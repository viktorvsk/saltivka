class RedisSearchCommands
  CREATE_SCHEMA_COMMAND = <<~REDIS
    FT.CREATE subscriptions_idx
    ON JSON
    PREFIX 1 subscriptions:
    SCHEMA $.kinds AS kinds TAG
           $.ids AS ids TAG
           $.authors AS authors TAG
           $.since AS since NUMERIC SORTABLE
           $.until AS until NUMERIC SORTABLE
           $.search AS search TEXT
           $.a AS a TAG CASESENSITIVE
           $.b AS b TAG CASESENSITIVE
           $.c AS c TAG CASESENSITIVE
           $.d AS d TAG CASESENSITIVE
           $.e AS e TAG CASESENSITIVE
           $.f AS f TAG CASESENSITIVE
           $.g AS g TAG CASESENSITIVE
           $.h AS h TAG CASESENSITIVE
           $.i AS i TAG CASESENSITIVE
           $.j AS j TAG CASESENSITIVE
           $.k AS k TAG CASESENSITIVE
           $.l AS l TAG CASESENSITIVE
           $.m AS m TAG CASESENSITIVE
           $.n AS n TAG CASESENSITIVE
           $.o AS o TAG CASESENSITIVE
           $.p AS p TAG CASESENSITIVE
           $.q AS q TAG CASESENSITIVE
           $.r AS r TAG CASESENSITIVE
           $.s AS s TAG CASESENSITIVE
           $.t AS t TAG CASESENSITIVE
           $.u AS u TAG CASESENSITIVE
           $.v AS v TAG CASESENSITIVE
           $.w AS w TAG CASESENSITIVE
           $.x AS x TAG CASESENSITIVE
           $.y AS y TAG CASESENSITIVE
           $.z AS z TAG CASESENSITIVE
           $.A AS A TAG CASESENSITIVE
           $.B AS B TAG CASESENSITIVE
           $.C AS C TAG CASESENSITIVE
           $.D AS D TAG CASESENSITIVE
           $.E AS E TAG CASESENSITIVE
           $.F AS F TAG CASESENSITIVE
           $.G AS G TAG CASESENSITIVE
           $.H AS H TAG CASESENSITIVE
           $.I AS I TAG CASESENSITIVE
           $.J AS J TAG CASESENSITIVE
           $.K AS K TAG CASESENSITIVE
           $.L AS L TAG CASESENSITIVE
           $.M AS M TAG CASESENSITIVE
           $.N AS N TAG CASESENSITIVE
           $.O AS O TAG CASESENSITIVE
           $.P AS P TAG CASESENSITIVE
           $.Q AS Q TAG CASESENSITIVE
           $.R AS R TAG CASESENSITIVE
           $.S AS S TAG CASESENSITIVE
           $.T AS T TAG CASESENSITIVE
           $.U AS U TAG CASESENSITIVE
           $.V AS V TAG CASESENSITIVE
           $.W AS W TAG CASESENSITIVE
           $.X AS X TAG CASESENSITIVE
           $.Y AS Y TAG CASESENSITIVE
           $.Z AS Z TAG CASESENSITIVE
  REDIS
end
