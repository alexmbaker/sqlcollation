using System;

namespace ChangeCollation
{
    public interface IScriptExecuteCallback
    {
        void ExecutionStarting(ScriptStepCollection script);

        bool Error(ScriptStep script, Exception ex);

        /// <summary>
        ///     reports progress being made
        /// </summary>
        /// <param name="script"></param>
        /// <param name="step"></param>
        /// <param name="stepMax"></param>
        /// <returns>return true if execution should continue</returns>
        bool Progress(ScriptStep script, int step, int stepMax);
    }
}