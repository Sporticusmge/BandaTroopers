import { useState } from 'react';

import { useBackend } from '../backend';
import { Box, Button, Section, Stack, Tabs } from '../components';
import { Window } from '../layouts';

export const MissionHubTrader = (props, context) => {
  const { data, act } = useBackend();
  const [tab, setTab] = useState('buy');
  const entries = tab === 'buy'
    ? data.offers
    : (data.can_manage ? data.sell_prices : data.sellables);

  return (
    <Window width={500} height={560} theme="ntos">
      <Window.Content scrollable>
        <Section
          title={data.trader_role === 'Quartermaster' ? 'Квартирмейстер' : 'Торговец'}
          color="good"
          buttons={<Box color="good">Снабжение корабля</Box>}>
          <Box color="label" mb={1}>
            Обмен снаряжением · только наличные
          </Box>
          <Tabs>
            <Tabs.Tab
              selected={tab === 'buy'}
              onClick={() => setTab('buy')}>
              Купить
            </Tabs.Tab>
            <Tabs.Tab
              selected={tab === 'sell'}
              onClick={() => setTab('sell')}>
              Продать
            </Tabs.Tab>
          </Tabs>
          {data.can_manage && (
            <Box color="good" mt={1}>
              ГМ: возьмите предмет и нажмите на торговца, чтобы настроить цену. Ноль удаляет его из выбранного каталога.
            </Box>
          )}
          <Stack vertical mt={1}>
            {entries?.map((entry) => (
              <Stack.Item key={entry.ref || entry.path}>
                <Section level={2}>
                  <Stack align="center">
                    <Stack.Item grow>
                      <Box bold color="good">
                        {entry.name}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Box color="label">${entry.price}</Box>
                    </Stack.Item>
                    {!data.can_manage && (
                      <Stack.Item>
                        <Button
                          color="good"
                          icon={tab === 'buy' ? 'cart-plus' : 'cash-register'}
                          onClick={() =>
                            act(tab, tab === 'buy' ? { path: entry.path } : { ref: entry.ref })
                          }>
                          {tab === 'buy' ? 'Купить' : 'Продать'}
                        </Button>
                      </Stack.Item>
                    )}
                    {data.can_manage && (
                      <Stack.Item>
                        <Button
                          color="bad"
                          icon="trash"
                          onClick={() => act('remove_offer', { path: entry.path, direction: tab })}
                        />
                      </Stack.Item>
                    )}
                  </Stack>
                </Section>
              </Stack.Item>
            ))}
            {!entries?.length && (
              <Stack.Item>
                <Box color="label" textAlign="center" mt={3}>
                  {tab === 'buy'
                    ? 'Снаряжение пока не выставлено.'
                    : data.can_manage
                      ? 'Список покупки у игроков пуст.'
                      : 'У вас нет выставленных предметов.'}
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
