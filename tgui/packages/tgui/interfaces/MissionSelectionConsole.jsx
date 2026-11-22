import { useBackend } from '../backend';
import { Box, Button, Section, Stack } from '../components';
import { Window } from '../layouts';

export const MissionSelectionConsole = (props, context) => {
  const { data, act } = useBackend();

  return (
    <Window width={560} height={500}>
      <Window.Content scrollable>
        <Section title="Следующая операция">
          <Box color="label">
            Выбрать операцию может любой игрок. Оплату за выполненное задание выдаёт ГМ.
          </Box>
          {data.current_mission && (
            <Box mt={1} color="good">
              Текущая операция: {data.current_mission}
              {data.current_objective && <Box mt={0.5}>Что нужно достать: {data.current_objective}</Box>}
              {data.current_extra_text && <Box mt={0.5}>{data.current_extra_text}</Box>}
              {data.current_reward != null && <Box mt={0.5}>Оплата за выполнение: ${data.current_reward} (выдаёт ГМ)</Box>}
            </Box>
          )}
        </Section>
        {(data.missions || []).map((mission) => (
          <Section key={mission.id} title={mission.name || mission.id}>
            <Stack align="center">
              <Stack.Item grow>
                <Box><b>Оплата за работу:</b> ${mission.reward || 0} (выдаёт ГМ)</Box>
                <Box mt={0.5} style={{ whiteSpace: 'pre-wrap' }}><b>Что нужно достать:</b> {mission.objective}</Box>
                {!!mission.extra_text && (
                  <Box mt={0.5} style={{ whiteSpace: 'pre-wrap' }}>{mission.extra_text}</Box>
                )}
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="good"
                  icon="play"
                  disabled={!data.can_select}
                  onClick={() => act('select_mission', { mission_id: mission.id })}
                >
                  Выбрать операцию
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        ))}
        {!data.missions?.length && (
          <Section>
            <Box color="label">
              Пока нет доступных операций. Попросите ГМ добавить задание.
            </Box>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
