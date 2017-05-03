using System;
using System.Data;
using System.Data.SqlClient;

namespace ChangeCollation
{
    public class ScriptStep
    {
        public ScriptStep(string commandText)
        {
            CommandText = commandText;
        }

        public ScriptRunState RunState { get; private set; }

        public string CommandText { get; }

        public SqlException Exception { get; private set; }

        public void Execute(SqlConnection connection, IScriptExecuteCallback callback)
        {
            if (RunState != ScriptRunState.None)
                throw new InvalidOperationException("Already Run");

            var command = connection.CreateCommand();
            command.CommandText = CommandText;
            command.CommandType = CommandType.Text;
            command.CommandTimeout = 0;

            RunState = ScriptRunState.Running;
            try
            {
                ExecuteCommand(command);
                RunState = ScriptRunState.Succeeded;
            }
            catch (SqlException ex)
            {
                Exception = ex;
                callback.Error(this, ex);
                RunState = ScriptRunState.Failed;
            }
        }

        /// <summary>
        ///     override this if data should be processed
        /// </summary>
        /// <param name="command"></param>
        protected virtual void ExecuteCommand(SqlCommand command)
        {
            command.ExecuteNonQuery();
        }
    }
}