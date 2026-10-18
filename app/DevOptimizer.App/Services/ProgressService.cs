using System;

namespace DevOptimizer.App.Services
{
    /// <summary>
    /// Service for managing progress indicators during long-running operations.
    /// </summary>
    public static class ProgressService
    {
        /// <summary>
        /// Reports progress for a long-running operation.
        /// </summary>
        /// <param name="percentage">Completion percentage (0-100)</param>
        /// <param name="message">Optional status message</param>
        public static void ReportProgress(int percentage, string? message = null)
        {
            // In a real implementation, this would update a progress bar or status indicator
            // For now, we'll just log it or update a shared state
            // The ViewModel will bind to properties that this service updates
        }

        /// <summary>
        /// Indicates that an operation has started.
        /// </summary>
        public static void StartOperation()
        {
            // Implementation would set IsBusy to true
        }

        /// <summary>
        /// Indicates that an operation has completed.
        /// </summary>
        public static void CompleteOperation()
        {
            // Implementation would set IsBusy to false and reset progress
        }
    }
}